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
import 'package:scribe/src/commands/downgrade.dart';
import 'package:scribe/src/commands/upgrade.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

/// The checkout the commands move.
const String checkoutDirectory = '/framework';

/// Where the executables this fake machine carries are written.
const String binDirectory = '/usr/bin';

/// The history of `VERSION`, as `git log --patch` writes it.
const String versionLog = '''
commit 9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c 2026-08-16T09:12:44+02:00
--- a/VERSION
+++ b/VERSION
-0.1.4
+0.1.5
commit 1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d 2026-08-15T18:03:10+02:00
--- a/VERSION
+++ b/VERSION
-0.1.3
+0.1.4
commit cafebabedeadbeef0123456789abcdefcafebabe 2026-08-14T11:41:02+02:00
--- /dev/null
+++ b/VERSION
+0.1.3
''';

/// A git that writes [becomes] into `VERSION` the moment a merge is asked for.
///
/// It is what makes an upgrade visible to a test: the real git moves the
/// working tree, and the command reads the file again afterwards.
class MergingProcessRunner extends RecordingProcessRunner {
  MergingProcessRunner({required this.becomes, super.outputs});

  /// The version the checkout carries once the merge has run.
  final String becomes;

  @override
  Future<int> run(List<String> command, {String? workingDirectory}) async {
    if (command.contains('merge')) fs.file('$checkoutDirectory/VERSION').writeAsStringSync('$becomes\n');

    return super.run(command, workingDirectory: workingDirectory);
  }
}

/// Writes a checkout carrying [version], cloned unless told otherwise.
void writeCheckout({String version = '0.1.5', bool cloned = true}) {
  for (final String directory in <String>['sdk', 'host', 'protocol']) {
    fs.directory('$checkoutDirectory/$directory').createSync(recursive: true);
  }

  fs.file('$checkoutDirectory/VERSION').writeAsStringSync('$version\n');
  if (cloned) fs.directory('$checkoutDirectory/.git').createSync(recursive: true);
}

/// Runs `scribe` with [args], every git call answered by [processes].
Future<int> runScribe(List<String> args, ProcessRunner processes) {
  for (final String executable in <String>['git', 'deno', 'npm', 'docker']) {
    fs.file('$binDirectory/$executable').createSync(recursive: true);
  }

  return runner.run(
    args,
    () => <ScribeCommand>[UpgradeCommand(), DowngradeCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: () => processes,
      Platform: () => const FakePlatform(environment: <String, String>{'PATH': binDirectory}),
    },
  );
}

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    logger = BufferLogger();
    writeCheckout();
    fs.currentDirectory = checkoutDirectory;
  });

  group('upgrade', () {
    test('it fast-forwards the checkout and says what moved', () async {
      final MergingProcessRunner processes = MergingProcessRunner(
        becomes: '0.2.0',
        outputs: <String, String>{'branch': 'main\n'},
      );

      expect(await runScribe(<String>['upgrade'], processes), 0);
      expect(
        processes.commands.map((List<String> command) => command.join(' ')),
        containsAll(<String>['git fetch origin main', 'git merge --ff-only origin/main']),
      );
      expect(logger.statusText, contains('scribe is now at 0.2.0, up from 0.1.5.'));
      expect(logger.statusText, contains('The tools you run are unchanged'));
    });

    test('a checkout already on the newest version is told so, not moved twice', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'branch': 'main\n'});

      expect(await runScribe(<String>['upgrade'], processes), 0);
      expect(logger.statusText, contains('scribe is already up to date at 0.1.5.'));
    });

    test('a detached checkout is put back on the release branch first', () async {
      final MergingProcessRunner processes = MergingProcessRunner(becomes: '0.2.0');

      await runScribe(<String>['upgrade'], processes);

      expect(
        processes.commands.map((List<String> command) => command.join(' ')),
        contains('git checkout main'),
      );
    });

    test('work that is not committed stops it before anything is fetched', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(
        outputs: <String, String>{'status': ' M host/api.ts\n'},
      );

      expect(await runScribe(<String>['upgrade'], processes), 1);
      expect(logger.errorText, contains('has changes that are not committed'));
      expect(processes.commands.map((List<String> command) => command.join(' ')), isNot(contains('git fetch')));
    });

    test('outside a checkout it says where it has to be run', () async {
      fs.currentDirectory = fs.directory('/elsewhere')..createSync();

      expect(await runScribe(<String>['upgrade'], RecordingProcessRunner()), 1);
      expect(logger.errorText, contains('No scribe checkout was found from here.'));
    });

    test('a copy that was never cloned has nowhere to move to', () async {
      fs.directory('$checkoutDirectory/.git').deleteSync(recursive: true);

      expect(await runScribe(<String>['upgrade'], RecordingProcessRunner()), 1);
      expect(logger.errorText, contains('is not a git clone'));
    });
  });

  group('downgrade', () {
    test('a version it is given is checked out by its commit', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'log': versionLog});

      expect(await runScribe(<String>['downgrade', '0.1.3'], processes), 0);
      expect(
        processes.commands.map((List<String> command) => command.join(' ')),
        contains('git -c advice.detachedHead=false checkout cafebabedeadbeef0123456789abcdefcafebabe'),
      );
      expect(logger.statusText, contains('scribe is now at 0.1.3, down from 0.1.5.'));
      expect(logger.statusText, contains('off any branch'));
    });

    test('the version it is on, and anything above it, are not offered', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'log': versionLog});

      expect(await runScribe(<String>['downgrade', '0.1.5'], processes), 64);
      expect(logger.errorText, contains('"0.1.5" is not a version this checkout can go back to.'));
      expect(logger.errorText, contains('It knows: 0.1.4, 0.1.3.'));
    });

    test('without a terminal it names the version to type instead of hanging', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'log': versionLog});

      expect(await runScribe(<String>['downgrade'], processes), 1);
      expect(logger.errorText, contains('scribe downgrade 0.1.4'));
    });

    test('a history with nothing older in it is a refusal that says why', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner();

      expect(await runScribe(<String>['downgrade'], processes), 1);
      expect(logger.errorText, contains('0.1.5 is the oldest version this checkout knows.'));
      expect(logger.errorText, contains('git fetch --unshallow'));
    });

    test('work that is not committed stops it too', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(
        outputs: <String, String>{'status': ' M host/api.ts\n', 'log': versionLog},
      );

      expect(await runScribe(<String>['downgrade', '0.1.3'], processes), 1);
      expect(logger.errorText, contains('has changes that are not committed'));
      expect(processes.commands.map((List<String> command) => command.join(' ')), isNot(contains('git checkout')));
    });
  });
}
