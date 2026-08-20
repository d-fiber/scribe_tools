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
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/commands/doctor.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;
late FakeCommand work;

/// Where the executables a test says are installed are written.
const String binDirectory = '/usr/bin';

/// Every tool a command is checked for.
const List<String> everyExecutable = <String>['git', 'deno', 'npm', 'docker'];

/// The framework checkout the version notice is read from.
const String checkoutDirectory = '/framework';

/// A command that needs nothing and reports whether it was reached.
class FakeCommand extends ScribeCommand {
  /// Whether the body of this command ran.
  bool ran = false;

  @override
  String get name => 'work';

  @override
  String get description => 'Do nothing, and say that it did.';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    ran = true;
    globals.logger.printStatus('working');
    return const ScribeCommandResult.success();
  }
}

/// A group whose whole run is printing its usage.
class FakeGroup extends ScribeCommandGroup {
  FakeGroup() {
    addSubcommand(FakeCommand());
  }

  @override
  String get name => 'group';

  @override
  String get description => 'Hold the command above.';
}

/// Runs `scribe` with [args] on a machine carrying [installed] and nothing else.
///
/// [processes] answers the git calls the version check makes; the default one
/// answers nothing, which is a checkout nobody has fetched.
Future<int> runScribe(
  List<String> args, {
  List<String> installed = everyExecutable,
  ProcessRunner? processes,
}) {
  for (final String executable in installed) {
    fs.file('$binDirectory/$executable').createSync(recursive: true);
  }

  return runner.run(
    args,
    () => <ScribeCommand>[work, FakeGroup(), DoctorCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: () => processes ?? RecordingProcessRunner(),
      Platform: () => const FakePlatform(
        operatingSystem: 'macos',
        environment: <String, String>{'PATH': binDirectory},
      ),
    },
  );
}

/// Writes a framework checkout at [checkoutDirectory] and runs the tests in it.
void writeCheckout({String version = '0.1.5'}) {
  for (final String directory in <String>['sdk', 'host', 'protocol', '.git']) {
    fs.directory('$checkoutDirectory/$directory').createSync(recursive: true);
  }

  fs.file('$checkoutDirectory/VERSION').writeAsStringSync('$version\n');
  fs.currentDirectory = checkoutDirectory;
}

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.currentDirectory = fs.directory('/elsewhere')..createSync();
    logger = BufferLogger();
    work = FakeCommand();
  });

  test('a machine that has everything hears nothing about it', () async {
    expect(await runScribe(<String>['work']), 0);
    expect(work.ran, isTrue);
    expect(logger.statusText, 'working\n');
  });

  test('a missing tool stops the command before it does anything', () async {
    final int status = await runScribe(<String>['work'], installed: <String>['git', 'npm', 'docker']);

    expect(status, 1);
    expect(work.ran, isFalse);
    expect(logger.statusText, isNot(contains('working')));
  });

  test('what it prints instead is the doctor, whole', () async {
    await runScribe(<String>['work'], installed: <String>['git', 'npm', 'docker', 'brew']);

    expect(logger.statusText, contains('[✓] Machine'));
    expect(logger.statusText, contains('[!] Tools'));
    expect(logger.statusText, contains('deno is missing'));
    expect(logger.statusText, contains('Run `scribe doctor --rescue` to fix what can be fixed from here.'));
    expect(logger.errorText, contains('scribe work needs every tool above'));
  });

  test('a subcommand is gated too, and named as it is typed', () async {
    await runScribe(<String>['group', 'work'], installed: <String>['git', 'npm', 'docker']);

    expect(logger.errorText, contains('scribe group work needs every tool above'));
  });

  test('a group is answered for the subcommand it lacks, not for the machine', () async {
    expect(await runScribe(<String>['group'], installed: <String>['git', 'npm', 'docker']), 64);
    expect(logger.errorText, contains('Missing subcommand'));
    expect(logger.statusText, isNot(contains('[!] Tools')));
  });

  test('doctor runs on a machine with nothing on it', () async {
    expect(await runScribe(<String>['doctor'], installed: <String>[]), 0);
    expect(logger.statusText, contains('[!] Tools'));
    expect(logger.errorText, isEmpty);
  });

  group('the version notice', () {
    test('a newer framework is said once, under what the command printed', () async {
      writeCheckout();

      await runScribe(<String>['work'], processes: RecordingProcessRunner(outputs: <String, String>{'show': '0.2.0'}));

      expect(logger.statusText, contains('working\n'));
      expect(logger.statusText, contains('A new version of scribe is available: 0.1.5 → 0.2.0'));
      expect(logger.statusText, contains('Run `scribe upgrade` to get it.'));
      expect(logger.statusText.indexOf('working'), lessThan(logger.statusText.indexOf('A new version')));
    });

    test('a checkout that is already current says nothing at all', () async {
      writeCheckout();

      await runScribe(<String>['work'], processes: RecordingProcessRunner(outputs: <String, String>{'show': '0.1.5'}));

      expect(logger.statusText, 'working\n');
    });

    test('outside a checkout there is no version to compare, and no git is run', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'show': '0.2.0'});

      await runScribe(<String>['work'], processes: processes);

      expect(logger.statusText, 'working\n');
      expect(processes.commands, isEmpty);
    });

    test('doctor carries the line under its tools instead of the notice', () async {
      writeCheckout();

      await runScribe(<String>['doctor'], processes: RecordingProcessRunner(outputs: <String, String>{'show': '0.2.0'}));

      expect(logger.statusText, contains('scribe 0.1.5, 0.2.0 is available'));
      expect(logger.statusText, contains('Run `scribe upgrade` to get it.'));
      expect(logger.statusText, isNot(contains('A new version of scribe is available')));
    });

    test('doctor lists the framework version it found even when it is current', () async {
      writeCheckout();

      await runScribe(<String>['doctor'], processes: RecordingProcessRunner(outputs: <String, String>{'show': '0.1.5'}));

      expect(logger.statusText, contains('✓ scribe 0.1.5'));
    });
  });
}
