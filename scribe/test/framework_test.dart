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
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/process.dart';
import 'package:scribe/src/framework.dart';
import 'package:scribe/src/updates.dart';
import 'package:scribe/src/version.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

/// The checkout every test here runs against.
const String checkoutDirectory = '/framework';

/// A `git log --patch -- VERSION` as git writes it, newest commit first.
const String versionLog = '''
commit 9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c 2026-08-16T09:12:44+02:00
diff --git a/VERSION b/VERSION
index 1234567..89abcde 100644
--- a/VERSION
+++ b/VERSION
@@ -1 +1 @@
-0.1.4
+0.1.5
commit 1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d 2026-08-15T18:03:10+02:00
diff --git a/VERSION b/VERSION
index 0123456..1234567 100644
--- a/VERSION
+++ b/VERSION
@@ -1 +1 @@
-0.1.3
+0.1.4
commit cafebabedeadbeef0123456789abcdefcafebabe 2026-08-14T11:41:02+02:00
diff --git a/VERSION b/VERSION
new file mode 100644
index 0000000..0123456
--- /dev/null
+++ b/VERSION
@@ -0,0 +1 @@
+0.1.3
''';

/// Writes a checkout carrying [version], a clone unless told otherwise.
void writeCheckout({String version = '0.1.5', bool cloned = true}) {
  for (final String directory in <String>['sdk', 'host', 'protocol']) {
    fs.directory('$checkoutDirectory/$directory').createSync(recursive: true);
  }

  fs.file('$checkoutDirectory/VERSION').writeAsStringSync('$version\n');
  if (cloned) fs.directory('$checkoutDirectory/.git').createSync(recursive: true);
}

/// Runs [body] with [processes] answering every git call.
Future<T> withProcesses<T>(ProcessRunner processes, Future<T> Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Logger: () => logger,
    ProcessRunner: () => processes,
  },
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
      fs.directory('$checkoutDirectory/host/api').createSync(recursive: true);
      fs.currentDirectory = '$checkoutDirectory/host/api';

      await withProcesses(RecordingProcessRunner(), () async {
        expect(Framework.locate()?.root.path, checkoutDirectory);
        expect(Framework.locate()?.version, const Version(0, 1, 5));
      });
    });

    test('a directory with no VERSION is not a checkout', () async {
      writeCheckout();
      fs.file('$checkoutDirectory/VERSION').deleteSync();
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

  group('the history of VERSION', () {
    test('every commit that wrote it becomes a release, newest first', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'log': versionLog}), () async {
        final List<Release> history = await Framework.locate()!.history();

        expect(history.map((Release release) => '${release.version}'), <String>['0.1.5', '0.1.4', '0.1.3']);
        expect(history.first.shortCommit, '9f8e7d6');
        expect(history.last.date, DateTime.parse('2026-08-14T11:41:02+02:00'));
      });
    });

    test('the first commit, which added the file, is a release like the others', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'log': versionLog}), () async {
        final Release first = (await Framework.locate()!.history()).last;

        expect(first.version, const Version(0, 1, 3));
        expect(first.commit, 'cafebabedeadbeef0123456789abcdefcafebabe');
      });
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

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '0.2.0\n'}), () async {
        expect(await pendingUpdate(Framework.locate()!), const Version(0, 2, 0));
      });
    });

    test('the same version, or an older one, is nothing to say', () async {
      writeCheckout();
      fs.currentDirectory = checkoutDirectory;

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '0.1.5\n'}), () async {
        expect(await pendingUpdate(Framework.locate()!), isNull);
      });

      await withProcesses(RecordingProcessRunner(outputs: <String, String>{'show': '0.1.4\n'}), () async {
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
