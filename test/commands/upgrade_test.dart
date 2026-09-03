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
import 'package:scribe_tools/src/commands/downgrade.dart';
import 'package:scribe_tools/src/commands/upgrade.dart';
import 'package:scribe_tools/src/package/sdk.dart' show kSdkWorkspaceFile;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

/// The checkout the commands move.
const String checkoutDirectory = '/framework';

/// Where the executables this fake machine carries are written.
const String binDirectory = '/usr/bin';

/// The tags a checkout carries, newest version first.
const String versionTags = '''
v0.1.5
v0.1.4
v0.1.3
''';

/// What `git log -1` answers for each of those tags.
const Map<String, String> taggedCommits = <String, String>{
  'v0.1.3': '0000000000000000000000000000000000000abc 2026-08-14T10:00:00+02:00',
  'v0.1.4': '0000000000000000000000000000000000000abd 2026-08-15T10:00:00+02:00',
  'v0.1.5': '0000000000000000000000000000000000000abe 2026-08-16T10:00:00+02:00',
};

/// A git that writes [becomes] into the configuration the moment a merge is asked for.
///
/// It is what makes an upgrade visible to a test: the real git moves the
/// working tree, and the command reads the file again afterwards.
class MergingProcessRunner extends RecordingProcessRunner {
  MergingProcessRunner({required this.becomes, super.outputs});

  /// The version the checkout carries once the merge has run.
  final String becomes;

  @override
  Future<int> run(List<String> command, {String? workingDirectory, Map<String, String>? environment}) async {
    if (command.contains('merge')) {
      fs.file('$checkoutDirectory/$kSdkWorkspaceFile').writeAsStringSync('{"version":"$becomes"}\n');
    }

    return super.run(command, workingDirectory: workingDirectory);
  }
}

/// Writes a checkout carrying [version], cloned unless told otherwise.
void writeCheckout({String version = '0.1.5', bool cloned = true}) {
  for (final String directory in <String>['sdk', 'engine', 'protocol']) {
    fs.directory('$checkoutDirectory/$directory').createSync(recursive: true);
  }

  fs.file('$checkoutDirectory/$kSdkWorkspaceFile').writeAsStringSync('{"version":"$version"}\n');
  if (cloned) fs.directory('$checkoutDirectory/.git').createSync(recursive: true);
}

/// Runs `scribe` with [args], every git call answered by [processes].
Future<int> runScribe(List<String> args, ProcessRunner processes) {
  for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
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
      expect(logger.statusText, contains('framework is now at 0.2.0, up from 0.1.5.'));
    });

    test('a checkout already on the newest version is told so, not moved twice', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(outputs: <String, String>{'branch': 'main\n'});

      expect(await runScribe(<String>['upgrade'], processes), 0);
      expect(logger.statusText, contains('framework is already up to date at 0.1.5.'));
    });

    test('a detached checkout is put back on the release branch first', () async {
      final MergingProcessRunner processes = MergingProcessRunner(becomes: '0.2.0');

      await runScribe(<String>['upgrade'], processes);

      expect(processes.commands.map((List<String> command) => command.join(' ')), contains('git checkout main'));
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
      final RecordingProcessRunner processes = RecordingProcessRunner(
        outputs: <String, String>{...taggedCommits, 'tag': versionTags},
      );

      expect(await runScribe(<String>['downgrade', '0.1.3'], processes), 0);
      expect(
        processes.commands.map((List<String> command) => command.join(' ')),
        contains('git -c advice.detachedHead=false checkout 0000000000000000000000000000000000000abc'),
      );
      expect(logger.statusText, contains('scribe is now at 0.1.3, down from 0.1.5.'));
      expect(logger.statusText, contains('off any branch'));
    });

    test('the version it is on, and anything above it, are not offered', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(
        outputs: <String, String>{...taggedCommits, 'tag': versionTags},
      );

      expect(await runScribe(<String>['downgrade', '0.1.5'], processes), 64);
      expect(logger.errorText, contains('"0.1.5" is not a version this checkout can go back to.'));
      expect(logger.errorText, contains('It knows: 0.1.4, 0.1.3.'));
    });

    test('without a terminal it names the version to type instead of hanging', () async {
      final RecordingProcessRunner processes = RecordingProcessRunner(
        outputs: <String, String>{...taggedCommits, 'tag': versionTags},
      );

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
        outputs: <String, String>{'status': ' M host/api.ts\n', ...taggedCommits, 'tag': versionTags},
      );

      expect(await runScribe(<String>['downgrade', '0.1.3'], processes), 1);
      expect(logger.errorText, contains('has changes that are not committed'));
      expect(processes.commands.map((List<String> command) => command.join(' ')), isNot(contains('git checkout')));
    });
  });
}
