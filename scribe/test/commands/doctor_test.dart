// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe/runner.dart' as runner;
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/io.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/platform.dart';
import 'package:scribe/src/base/process.dart';
import 'package:scribe/src/commands/doctor.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/secrets.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;
late RecordingProcessRunner processes;

/// The root of the project the tests run in.
const String projectDirectory = '/work/koko';

/// Where the executables a test says are installed are written.
const String binDirectory = '/usr/bin';

/// A manifest with nothing missing, so the project section is quiet.
const String completeManifest = '''
name: "koko"
url: "https://koko.example.com"
email: "dev@koko.example.com"

dependencies:
  - security/auth
  - security/rbac

api:
  config:
    origins:
      - "https://koko.example.com"
    allowed_countries: ["FR"]
''';

/// Runs `scribe` with [args] on a machine carrying [installed] and nothing else.
///
/// The `PATH` and the file system are the whole machine here: `which` walks
/// them and starts no process, so what a test says is installed is what the
/// command finds.
Future<int> runScribe(List<String> args, {List<String> installed = const <String>[]}) {
  for (final String executable in installed) {
    fs.file('$binDirectory/$executable').createSync(recursive: true);
  }

  return runner.run(
    args,
    () => <ScribeCommand>[DoctorCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: () => processes,
      Platform: () => FakePlatform(
        operatingSystem: 'macos',
        environment: const <String, String>{'PATH': binDirectory, 'SHELL': '/bin/zsh', 'HOME': '/home'},
      ),
    },
  );
}

/// Writes a project at [projectDirectory], complete unless told otherwise.
void writeProject({String manifest = completeManifest, bool withLib = true}) {
  fs.file('$projectDirectory/config.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync(manifest);

  if (!withLib) return;

  fs.file('$projectDirectory/lib/main.ts').createSync(recursive: true);
  fs.directory('$projectDirectory/lib/src').createSync(recursive: true);
}

/// Every tool the report looks for, plus the package manager of this fake machine.
const List<String> everything = <String>['git', 'deno', 'npm', 'docker', 'brew'];

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory(projectDirectory).createSync(recursive: true);
    fs.currentDirectory = projectDirectory;
    logger = BufferLogger();
    processes = RecordingProcessRunner();
  });

  group('what it reports', () {
    test('the tools are listed one per line, their paths in a column', () async {
      writeProject();

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('[✓] Machine'));
      expect(logger.statusText, contains('[✓] Tools'));
      expect(logger.statusText, contains('git    $binDirectory/git'));
      expect(logger.statusText, contains('docker $binDirectory/docker'));
      expect(logger.statusText, contains('No issues found!'));
    });

    test('a project with nothing missing is not a section, it is silence', () async {
      writeProject();

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, isNot(contains('Project')));
    });

    test('-v prints the project entries the report keeps to itself', () async {
      writeProject();

      expect(await runScribe(<String>['doctor', '-v'], installed: everything), 0);
      expect(logger.statusText, contains('[✓] Project (koko)'));
      expect(logger.statusText, contains('config.yaml is here'));
      expect(logger.statusText, contains('lib/main.ts is here'));
    });

    test('a missing tool names the command that installs it', () async {
      writeProject();

      expect(await runScribe(<String>['doctor'], installed: <String>['git', 'deno', 'npm', 'brew']), 0);
      expect(logger.statusText, contains('[!] Tools'));
      expect(logger.statusText, contains('git    $binDirectory/git'));
      expect(logger.statusText, contains('docker is missing'));
      expect(logger.statusText, contains('Run `brew install docker` to install it.'));
      expect(logger.statusText, contains('Doctor found issues in 1 category.'));
      expect(logger.statusText, contains('Run `scribe doctor --rescue` to fix what can be fixed from here.'));
    });

    test('without a package manager, a missing tool points at its homepage', () async {
      writeProject();

      expect(await runScribe(<String>['doctor'], installed: <String>['git', 'deno', 'npm']), 0);
      expect(logger.statusText, contains('Install it from https://'));
      expect(logger.statusText, isNot(contains('to install it.')));
      expect(logger.statusText, contains('no package manager found'));
    });

    test('outside a project, that is a note and not a problem', () async {
      fs.currentDirectory = fs.directory('/elsewhere')..createSync();

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('[✓] Project (none here)'));
      expect(logger.statusText, contains('Run `scribe create <name>` to start one'));
      expect(logger.statusText, contains('No issues found!'));
    });

    test('a directory a project is missing says which command creates it', () async {
      writeProject(withLib: false);

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('lib/ is missing'));
      expect(logger.statusText, contains('lib/src/ is missing'));
      expect(logger.statusText, contains('Run `scribe doctor --rescue` to create it.'));
    });

    test('an entrypoint cannot be invented, and the report says what it is', () async {
      writeProject(withLib: false);

      await runScribe(<String>['doctor'], installed: everything);

      expect(logger.statusText, contains('lib/main.ts is missing'));
      expect(logger.statusText, contains('It is the file the host loads the project through'));
    });

    test('a field the manifest is missing is named with the file to fill it in', () async {
      writeProject(manifest: 'name: "koko"\n');

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('Fill `url` in config.yaml.'));
      expect(logger.statusText, contains('Fill `email` in config.yaml.'));
    });

    test('a secrets file nobody holds the key for is a problem of its own', () async {
      writeProject();
      fs.file('$projectDirectory/${SecretsStore.fileName}').createSync(recursive: true);

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('${SecretsStore.fileName} is here, but no key opens it'));
      expect(logger.statusText, contains('\$$kIdentityVariable'));
    });
  });

  group('--rescue', () {
    test('creates the directories the project is missing, then says what is left', () async {
      writeProject(withLib: false);

      expect(await runScribe(<String>['doctor', '--rescue'], installed: everything), 0);
      expect(fs.directory('$projectDirectory/lib/src').existsSync(), isTrue);
      expect(logger.statusText, contains('Repairing what can be repaired from here.'));
      expect(logger.statusText, isNot(contains('lib/src/ is missing\n      Run')));
      expect(logger.statusText, contains('lib/main.ts is missing'));
    });

    test('installs a missing tool with the package manager of the machine', () async {
      writeProject();

      expect(
        await runScribe(<String>['doctor', '--rescue', '--yes'], installed: <String>['git', 'deno', 'npm', 'brew']),
        0,
      );
      expect(
        processes.commands.map((List<String> command) => command.join(' ')),
        contains('brew install docker'),
      );
    });

    test('says so when there is nothing it can do, and reports all the same', () async {
      writeProject(manifest: 'name: "koko"\n');

      expect(await runScribe(<String>['doctor', '--rescue'], installed: everything), 0);
      expect(logger.statusText, contains('There is nothing --rescue can do from here.'));
      expect(logger.statusText, contains('Fill `url` in config.yaml.'));
    });

    test('a healthy machine is left alone', () async {
      writeProject();

      expect(await runScribe(<String>['doctor', '--rescue'], installed: everything), 0);
      expect(processes.commands, isEmpty);
      expect(logger.statusText, contains('No issues found!'));
    });
  });
}
