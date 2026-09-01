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

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:scribe_tools/src/base/watch.dart';
import 'package:test/test.dart';

const LocalFileSystem _fs = LocalFileSystem();

void main() {
  group('FakeWatcher', () {
    test('pulses every open stream once per change', () async {
      final FakeWatcher watcher = FakeWatcher();
      final List<void> first = <void>[];
      final List<void> second = <void>[];
      final StreamSubscription<void> a = watcher.watch(const <FileSystemEntity>[]).listen(first.add);
      final StreamSubscription<void> b = watcher.watch(const <FileSystemEntity>[]).listen(second.add);

      watcher
        ..change()
        ..change();
      await Future<void>.delayed(Duration.zero);

      expect(first.length, 2);
      expect(second.length, 2);

      await a.cancel();
      await b.cancel();
    });

    test('stop ends every open stream', () async {
      final FakeWatcher watcher = FakeWatcher();
      bool done = false;
      final StreamSubscription<void> subscription = watcher
          .watch(const <FileSystemEntity>[])
          .listen(null, onDone: () => done = true);

      await watcher.stop();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
      await subscription.cancel();
    });

    test('records what each call to watch was given', () {
      final FakeWatcher watcher = FakeWatcher();
      final Directory a = _fs.directory('/one');
      final Directory b = _fs.directory('/two');

      watcher
        ..watch(<FileSystemEntity>[a])
        ..watch(<FileSystemEntity>[b]);

      expect(watcher.requests, <List<FileSystemEntity>>[
        <FileSystemEntity>[a],
        <FileSystemEntity>[b],
      ]);
    });
  });

  group('LocalWatcher', () {
    test('an entity that does not exist yet is skipped, answering an empty stream', () async {
      const LocalWatcher watcher = LocalWatcher();

      final List<void> pulses = <void>[];
      await watcher.watch(<FileSystemEntity>[_fs.directory('/nowhere/scribe-watch-test')]).forEach(pulses.add);

      expect(pulses, isEmpty);
    });

    test('a burst of writes to a watched directory pulses once, after debounce', () async {
      final io.Directory real = io.Directory.systemTemp.createTempSync('scribe_watch_test');
      addTearDown(() => real.deleteSync(recursive: true));

      const LocalWatcher watcher = LocalWatcher();
      final List<void> pulses = <void>[];
      final StreamSubscription<void> subscription = watcher
          .watch(<FileSystemEntity>[_fs.directory(real.path)], debounce: const Duration(milliseconds: 50))
          .listen(pulses.add);

      io.File('${real.path}/a.txt').writeAsStringSync('one');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      io.File('${real.path}/a.txt').writeAsStringSync('two');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await subscription.cancel();

      expect(pulses.length, 1);
    });
  });
}
