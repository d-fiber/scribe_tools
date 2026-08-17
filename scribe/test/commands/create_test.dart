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
import 'package:scribe/src/commands/create.dart';
import 'package:scribe/src/commands/create/sdk_choice.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/sdk_target.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

/// The directory `create` is run from, one below the framework.
const String workDirectory = '/framework/work';

/// Where the executables this fake machine carries are written.
const String binDirectory = '/usr/bin';

/// Puts every tool a command checks for on this machine's `PATH`.
///
/// Each command opens by looking for them and refuses with the doctor's report
/// when one is missing, so a machine carrying nothing would answer every test
/// below with that report instead of what it is about.
void writeMachine() {
  for (final String executable in <String>['git', 'deno', 'npm', 'docker']) {
    fs.file('$binDirectory/$executable').createSync(recursive: true);
  }
}

/// Runs `scribe` with [args] against the memory file system and the buffer.
///
/// Nothing here has a terminal, so no menu can ever open: a test that reaches
/// one would otherwise wait for a keystroke that never comes.
Future<int> runScribe(List<String> args) => runner.run(
  args,
  () => <ScribeCommand>[CreateCommand()],
  toolVersion: 'test',
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Logger: () => logger,
    Stdio: FakeStdio.new,
    Platform: () => const FakePlatform(environment: <String, String>{'PATH': binDirectory}),
  },
);

/// Writes a framework checkout at `/framework`, with a template per SDK.
///
/// [sdks] names the directories of `sdk/`, each given one hand-written file so
/// it counts as ready. [templates] names the layers of `templates/`, `common`
/// included, so a test can drop the one it wants missing.
void writeFramework({
  Map<String, String> sdks = const <String, String>{'js': '.ts', 'dart': '.dart'},
  List<String> templates = const <String>['common', 'js'],
}) {
  fs.directory('/framework/host').createSync(recursive: true);
  fs.directory('/framework/protocol').createSync(recursive: true);

  sdks.forEach((String name, String extension) {
    fs.file('/framework/sdk/$name/client$extension').createSync(recursive: true);
  });

  for (final String layer in templates) {
    if (layer == 'common') {
      fs.file('/framework/templates/common/gitignore')
        ..createSync(recursive: true)
        ..writeAsStringSync('/{{name}}.log\n');
      fs.file('/framework/templates/common/config.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: {{name}}\nhost: {{host}}\nsdk: {{sdk}}\n');
      fs.file('/framework/templates/common/lib/main.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('the shared entrypoint\n');
      fs.file('/framework/templates/common/tests/.gitkeep').createSync(recursive: true);
      continue;
    }

    fs.file('/framework/templates/$layer/lib/main.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('the $layer entrypoint of {{name}}\n');
  }
}

String contentOf(String path) => fs.file(path).readAsStringSync();

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory(workDirectory).createSync(recursive: true);
    fs.currentDirectory = workDirectory;
    logger = BufferLogger();
    writeMachine();
  });

  group('the name it is given', () {
    test('a create without a name says what the name is for, and prints the options', () async {
      writeFramework();

      expect(await runScribe(<String>['create']), 64);
      expect(logger.errorText, contains('scribe create needs a <name>.'));
      expect(logger.errorText, contains('import alias'));
      expect(logger.errorText, contains('scribe create my_app --sdk ts'));
      expect(logger.statusText, contains('Usage: scribe create <name>'));
      expect(logger.statusText, contains('--sdk'));
      expect(fs.directory('$workDirectory/name').existsSync(), isFalse);
    });

    test('a second word is refused rather than dropped', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'one', 'two', 'three']), 64);
      expect(logger.errorText, contains('takes a single <name>'));
      expect(logger.errorText, contains('"one"'));
      expect(logger.errorText, contains('"two", "three"'));
      expect(fs.directory('$workDirectory/one').existsSync(), isFalse);
    });

    test('the options of the command are printed under the refusal', () async {
      writeFramework();

      await runScribe(<String>['create', 'one', 'two']);

      expect(logger.statusText, contains('Usage: scribe create <name>'));
    });

    for (final String refused in <String>['Foo', '1st', '-', 'my.app', '_app', 'app!']) {
      test('"$refused" cannot name a project', () async {
        writeFramework();

        expect(await runScribe(<String>['create', refused]), 1);
        expect(logger.errorText, contains('cannot name a project'));
        expect(fs.directory('$workDirectory/$refused').existsSync(), isFalse);
      });
    }

    for (final String accepted in <String>['a', 'my_app', 'my-app', 'app2']) {
      test('"$accepted" names a project', () async {
        writeFramework();

        expect(await runScribe(<String>['create', accepted, '--sdk', 'js']), 0);
        expect(fs.directory('$workDirectory/$accepted').existsSync(), isTrue);
      });
    }

    test('an existing directory is never merged into', () async {
      writeFramework();
      fs.directory('$workDirectory/taken/lib').createSync(recursive: true);

      expect(await runScribe(<String>['create', 'taken', '--sdk', 'js']), 1);
      expect(logger.errorText, contains('already exists'));
      expect(fs.file('$workDirectory/taken/config.yaml').existsSync(), isFalse);
    });
  });

  group('the SDK it targets', () {
    test('a missing name and a wrong SDK are said in the same refusal', () async {
      writeFramework();

      expect(await runScribe(<String>['create', '--sdk', 'd']), 64);
      expect(logger.errorText, contains('scribe create needs a <name>.'));
      expect(logger.errorText, contains('"d" is not an SDK this framework carries'));
      expect(logger.errorText, contains('dart, ts'));
    });

    test('a wrong SDK is said alongside the words in excess too', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'one', 'two', '--sdk', 'd']), 64);
      expect(logger.errorText, contains('takes a single <name>'));
      expect(logger.errorText, contains('"d" is not an SDK this framework carries'));
    });

    test('the SDKs on disk are named in the help of the option', () async {
      writeFramework();

      expect(await runScribe(<String>['create', '--sdk']), 64);
      expect(logger.errorText, contains('Missing argument for "--sdk"'));
      expect(logger.statusText, contains('one of dart, ts'));
    });

    test('the help of the option says nothing of the SDKs when there is no framework', () async {
      fs.currentDirectory = fs.directory('/elsewhere')..createSync();

      expect(await runScribe(<String>['create', '--sdk']), 64);
      expect(logger.statusText, contains('The SDK the endpoints are written against.'));
      expect(logger.statusText, isNot(contains('one of')));
    });

    test('an SDK the framework does not carry is refused with the list of the ones it has', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'cobol']), 64);
      expect(logger.errorText, contains('"cobol" is not an SDK this framework carries'));
      expect(logger.errorText, contains('dart, ts'));
      expect(logger.statusText, contains('Usage: scribe create <name>'));
    });

    test('an empty SDK directory is refused, with the ones that would work', () async {
      writeFramework(sdks: const <String, String>{'js': '.ts'});
      fs.directory('/framework/sdk/go').createSync(recursive: true);

      expect(await runScribe(<String>['create', 'app', '--sdk', 'go']), 1);
      expect(logger.errorText, contains('sdk/go/ is an empty directory'));
      expect(logger.errorText, contains('Pick another SDK: ts.'));
      expect(fs.directory('$workDirectory/app').existsSync(), isFalse);
    });

    test('an SDK holding nothing but generated files works, and says what it costs', () async {
      writeFramework(sdks: const <String, String>{'js': '.ts'});
      fs.file('/framework/sdk/go/gen/client.go').createSync(recursive: true);

      expect(await runScribe(<String>['create', 'app', '--sdk', 'go']), 0);
      expect(logger.warningText, contains('The Go SDK is not usable yet'));
      expect(fs.directory('$workDirectory/app').existsSync(), isTrue);
    });

    test('the only SDK available is taken, and said out loud', () async {
      writeFramework(sdks: const <String, String>{'js': '.ts'});

      expect(await runScribe(<String>['create', 'app']), 0);
      expect(logger.statusText, contains('Only one SDK is available, TS.'));
      expect(contentOf('$workDirectory/app/config.yaml'), contains('sdk: js'));
    });

    test('with nothing to ask on, the default is taken and the reason is given', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app']), 0);
      expect(logger.statusText, contains('Using the TS SDK: nothing to ask on to pick another.'));
    });

    test('"ts" and "js" both name the SDK the js directory holds', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'typed', '--sdk', 'ts']), 0);
      expect(contentOf('$workDirectory/typed/config.yaml'), contains('sdk: js'));
      expect(fs.file('$workDirectory/typed/lib/main.txt').readAsStringSync(), 'the js entrypoint of typed\n');

      expect(await runScribe(<String>['create', 'spelled', '--sdk', 'JS']), 0);
      expect(contentOf('$workDirectory/spelled/config.yaml'), contains('sdk: js'));
    });

    test('the menu lists the SDKs by label, whatever order they were found in', () {
      final List<SdkTarget> ordered = SdkChoice.orderedForMenu(const <SdkTarget>[
        SdkTarget.assumed('js'),
        SdkTarget.assumed('rust'),
        SdkTarget.assumed('dart'),
      ]);

      expect(<String>[for (final SdkTarget target in ordered) target.label], <String>['Dart', 'Rust', 'TS']);
    });

    test('a project can be created against an SDK with no template, with a warning', () async {
      writeFramework(templates: const <String>['common']);

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      expect(logger.warningText, contains('There is no template for the TS SDK'));
      expect(contentOf('$workDirectory/app/lib/main.txt'), 'the shared entrypoint\n');
    });
  });

  group('what it writes', () {
    test('the SDK layer wins file by file, and the shared one fills the rest', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      expect(contentOf('$workDirectory/app/lib/main.txt'), 'the js entrypoint of app\n');
      expect(fs.file('$workDirectory/app/tests/.gitkeep').existsSync(), isTrue);
    });

    test('the placeholders are filled in, the host name losing its underscores', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'my_app', '--sdk', 'js']), 0);
      expect(contentOf('$workDirectory/my_app/config.yaml'), 'name: my_app\nhost: my-app\nsdk: js\n');
    });

    test('a dotless gitignore template lands as a .gitignore', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      expect(fs.file('$workDirectory/app/.gitignore').existsSync(), isTrue);
      expect(contentOf('$workDirectory/app/.gitignore'), '/app.log\n');
    });

    test('a keeper file is written empty, not rendered', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      expect(contentOf('$workDirectory/app/tests/.gitkeep'), isEmpty);
    });

    test('the derived directory is created with its three subdirectories', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      for (final String derived in <String>['docs', 'ops', 'sdk']) {
        expect(fs.directory('$workDirectory/app/.app/$derived').existsSync(), isTrue, reason: derived);
      }
    });

    test('nothing is written when there is no framework above the directory', () async {
      fs.currentDirectory = fs.directory('/elsewhere')..createSync();

      expect(await runScribe(<String>['create', 'app']), 1);
      expect(logger.errorText, contains('there is no scribe checkout above'));
      expect(fs.directory('/elsewhere/app').existsSync(), isFalse);
    });
  });

  group('what it reports', () {
    test('the count of the files, then the commands to type next', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js']), 0);
      expect(logger.statusText, contains('Wrote 4 files.'));
      expect(logger.statusText, contains('All done!'));
      expect(logger.statusText, contains(r'  $ cd app'));
      expect(logger.statusText, contains(r'  $ scribe doctor'));
      expect(logger.statusText, contains('app/config.yaml'));
      expect(logger.statusText, contains('app/lib/main.ts'));
    });

    test('the paths themselves are traced, not printed', () async {
      writeFramework();

      await runScribe(<String>['create', 'app', '--sdk', 'js']);

      expect(logger.traceText, contains('wrote config.yaml'));
      expect(logger.statusText, isNot(contains('wrote config.yaml')));
    });

    test('-v says what the bracket means, and that the command went through', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js', '-v']), 0);
      expect(logger.statusText, contains('the time since the line above'));
      expect(logger.statusText, contains('scribe create finished in'));
    });

    test('a command that was stopped says so instead of reporting a duration', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'Foo', '-v']), 1);
      expect(logger.statusText, contains('scribe create stopped after'));
      expect(logger.statusText, isNot(contains('finished in')));
    });

    test('-q keeps the errors and drops everything else', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk', 'js', '-q']), 0);
      expect(logger.statusText, isEmpty);
      expect(fs.file('$workDirectory/app/config.yaml').existsSync(), isTrue);
    });
  });

  group('the options it is given', () {
    test('an option the command does not know is refused, with its usage', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--nope']), 64);
      expect(logger.errorText, contains('Could not find an option named "--nope"'));
      expect(logger.statusText, contains('Usage: scribe create <name>'));
    });

    test('an option given no value is refused', () async {
      writeFramework();

      expect(await runScribe(<String>['create', 'app', '--sdk']), 64);
      expect(logger.errorText, contains('sdk'));
    });

    test('the help of the SDK option is wrapped rather than run onto one line', () async {
      final CreateCommand command = CreateCommand();

      expect(
        command.argParser.usage.split('\n').map((String line) => line.length),
        everyElement(lessThanOrEqualTo(kDefaultTerminalColumns)),
      );
    });
  });
}
