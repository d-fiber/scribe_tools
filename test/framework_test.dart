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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/package/sdk.dart' show kSdkWorkspaceFile;
import 'package:scribe_tools/src/self/updates.dart';
import 'package:scribe_tools/src/self/version.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

/// The checkout every test here runs against.
const String checkoutDirectory = '/framework';

/// The tags a checkout carries, newest version first, as `git tag --list` writes them.
const String versionTags = '''
v0.1.5
v0.1.4
v0.1.3
''';

/// What `git log -1` answers for each of those tags.
const Map<String, String> taggedCommits = <String, String>{
  'v0.1.5': '9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c 2026-08-16T09:12:44+02:00',
  'v0.1.4': '1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d 2026-08-15T18:03:10+02:00',
  'v0.1.3': 'cafebabedeadbeef0123456789abcdefcafebabe 2026-08-14T11:41:02+02:00',
};

/// Writes a checkout carrying [version], a clone unless told otherwise.
void writeCheckout({String version = '0.1.5', bool cloned = true}) {
  for (final String directory in <String>['sdk', 'engine', 'protocol']) {
    fs.directory('$checkoutDirectory/$directory').createSync(recursive: true);
  }

  fs.file('$checkoutDirectory/$kSdkWorkspaceFile').writeAsStringSync('{"version":"$version"}\n');
  if (cloned) fs.directory('$checkoutDirectory/.git').createSync(recursive: true);
}

/// Runs [body] with [processes] answering every git call.
Future<T> withProcesses<T>(ProcessRunner processes, Future<T> Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{FileSystem: () => fs, Logger: () => logger, ProcessRunner: () => processes},
  body: body,
);

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    logger = BufferLogger();
  });

  group('finding the checkout', () {
    test('it is found from a directory below it', () async {
      writeCheckout();
      fs.directory('$checkoutDirectory/engine/api').createSync(recursive: true);
      fs.currentDirectory = '$checkoutDirectory/engine/api';

      await withProcesses(RecordingProcessRunner(), () async {
        expect(Framework.locate()?.root.path, checkoutDirectory);
        expect(Framework.locate()?.version, const Version(0, 1, 5));
      });
    });

    test('a directory with no scribe.workspace.json is not a checkout', () async {
      writeCheckout();
      fs.file('$checkoutDirectory/$kSdkWorkspaceFile').deleteSync();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(), () async {
        expect(Framework.locate(), isNull);
      });
    });

    test('a copy that was never cloned is found, but cannot be moved', () async {
      writeCheckout(cloned: false);
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(), () async {
        expect(Framework.locate()?.isClone, isFalse);
      });
    });
  });

  group('the history the tags carry', () {
    test('every tag becomes a release, newest first', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(
        RecordingProcessRunner(outputs: <String, String>{...taggedCommits, 'tag': versionTags}),
        () async {
          final List<Release> history = await Framework.locate()!.history();

          expect(history.map((Release release) => '${release.version}'), <String>['0.1.5', '0.1.4', '0.1.3']);
          expect(history.first.shortCommit, '9f8e7d6');
          expect(history.last.date, DateTime.parse('2026-08-14T11:41:02+02:00'));
        },
      );
    });

    test('the oldest tag is a release like the others', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(
        RecordingProcessRunner(outputs: <String, String>{...taggedCommits, 'tag': versionTags}),
        () async {
          final Release first = (await Framework.locate()!.history()).last;

          expect(first.version, const Version(0, 1, 3));
          expect(first.commit, 'cafebabedeadbeef0123456789abcdefcafebabe');
        },
      );
    });

    test('a log that says nothing is no history, not a crash', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(), () async {
        expect(await Framework.locate()!.history(), isEmpty);
      });
    });
  });

  group('what the working tree is worth', () {
    test('an empty status is a clean checkout', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'status': '\n'}), () async {
        expect(await Framework.locate()!.isClean(), isTrue);
      });
    });

    test('a status with a line in it is not', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'status': ' M host/api.ts\n'}), () async {
        expect(await Framework.locate()!.isClean(), isFalse);
      });
    });
  });

  group('the update it hears about', () {
    test('a newer version on the release branch is the pending one', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '{"version":"0.2.0"}\n'}), () async {
        expect(await pendingUpdate(Framework.locate()!), const Version(0, 2, 0));
      });
    });

    test('the same version, or an older one, is nothing to say', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '{"version":"0.1.5"}\n'}), () async {
        expect(await pendingUpdate(Framework.locate()!), isNull);
      });

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '{"version":"0.1.4"}\n'}), () async {
        expect(await pendingUpdate(Framework.locate()!), isNull);
      });
    });

    test('a branch nobody fetched answers nothing, and no version is invented', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(), () async {
        expect(await pendingUpdate(Framework.locate()!), isNull);
      });
    });
  });

  group('the fetch that runs behind the command', () {
    test('it is started detached, and the marker is written first', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;
      final RecordingProcessRunner processes = RecordingProcessRunner();

      await withProcesses(processes, () async {
        scheduleFetch(Framework.locate()!);
      });

      expect(fs.file('$checkoutDirectory/.git/$kFetchMarker').existsSync(), isTrue);
      expect(processes.commands.single, <String>[
        'git',
        '-C',
        checkoutDirectory,
        'fetch',
        '--quiet',
        kOrigin,
        kReleaseBranch,
      ]);
    });

    test('a fetch started an hour ago is recent enough to skip', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;
      fs.file('$checkoutDirectory/.git/$kFetchMarker')
        ..createSync(recursive: true)
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

      final RecordingProcessRunner processes = RecordingProcessRunner();
      await withProcesses(processes, () async {
        scheduleFetch(Framework.locate()!);
      });

      expect(processes.commands, isEmpty);
    });

    test('one from two days ago is not', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;
      fs.file('$checkoutDirectory/.git/$kFetchMarker')
        ..createSync(recursive: true)
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));

      final RecordingProcessRunner processes = RecordingProcessRunner();
      await withProcesses(processes, () async {
        scheduleFetch(Framework.locate()!);
      });

      expect(processes.commands, hasLength(1));
    });
  });
}
