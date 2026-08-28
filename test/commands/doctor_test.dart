// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/commands/doctor.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/secrets.dart';
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

dependencies:
  - auth
  - audience

api:
  url: "https://koko.example.com"
  cors:
    - "https://koko.example.com"
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
      Platform: () => const FakePlatform(
        operatingSystem: 'macos',
        environment: <String, String>{'PATH': binDirectory, 'SHELL': '/bin/zsh', 'HOME': '/home'},
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

  fs.directory('$projectDirectory/lib/app').createSync(recursive: true);
}

/// Every tool the report looks for, plus the package manager of this fake machine.
const List<String> everything = <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync', 'brew'];

/// Where the path of [tool] starts on its line of the report.
int _columnOf(String report, String tool) {
  final String line = report.split('\n').firstWhere((String line) => line.trim().startsWith('✓ $tool'));

  return line.indexOf('/');
}

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
      expect(logger.statusText, matches(RegExp('git +$binDirectory/git')));
      expect(logger.statusText, matches(RegExp('docker +$binDirectory/docker')));
      expect(
        _columnOf(logger.statusText, 'git'),
        _columnOf(logger.statusText, 'docker'),
        reason: 'the paths line up under each other, whatever the longest name is',
      );
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
    });

    test('a missing tool names the command that installs it', () async {
      writeProject();

      expect(
        await runScribe(<String>['doctor'], installed: <String>['git', 'deno', 'npm', 'tofu', 'ssh', 'rsync', 'brew']),
        0,
      );
      expect(logger.statusText, contains('[!] Tools'));
      expect(logger.statusText, matches(RegExp('git +$binDirectory/git')));
      expect(logger.statusText, contains('docker is missing'));
      expect(logger.statusText, contains('Run `brew install docker` to install it.'));
      expect(logger.statusText, contains('Doctor found issues in 1 category.'));
      expect(logger.statusText, contains('Run `scribe doctor --rescue` to fix what can be fixed from here.'));
    });

    test('without a package manager, a missing tool points at its homepage', () async {
      writeProject();

      expect(await runScribe(<String>['doctor'], installed: <String>['git', 'deno', 'npm', 'tofu', 'ssh', 'rsync']), 0);
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
      expect(logger.statusText, contains('Run `scribe doctor --rescue` to create it.'));
    });

    test('a field the manifest is missing is named with the file to fill it in', () async {
      writeProject(manifest: 'dependencies:\n');

      expect(await runScribe(<String>['doctor'], installed: everything), 0);
      expect(logger.statusText, contains('Fill `name` in config.yaml.'));
      expect(logger.statusText, contains('Fill `api.cors` in config.yaml.'));
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
      expect(fs.directory('$projectDirectory/lib').existsSync(), isTrue);
      expect(logger.statusText, contains('Repairing what can be repaired from here.'));
      expect(logger.statusText, isNot(contains('lib/ is missing\n      Run')));
    });

    test('installs a missing tool with the package manager of the machine', () async {
      writeProject();

      expect(
        await runScribe(<String>['doctor', '--rescue', '--yes'], installed: <String>['git', 'deno', 'npm', 'brew']),
        0,
      );
      expect(processes.commands.map((List<String> command) => command.join(' ')), contains('brew install docker'));
    });

    test('says so when there is nothing it can do, and reports all the same', () async {
      writeProject(manifest: 'dependencies:\n');

      expect(await runScribe(<String>['doctor', '--rescue'], installed: everything), 0);
      expect(logger.statusText, contains('There is nothing --rescue can do from here.'));
      expect(logger.statusText, contains('Fill `name` in config.yaml.'));
    });

    test('a healthy machine is left alone', () async {
      writeProject();

      expect(await runScribe(<String>['doctor', '--rescue'], installed: everything), 0);
      expect(processes.commands, isEmpty);
      expect(logger.statusText, contains('No issues found!'));
    });
  });
}
