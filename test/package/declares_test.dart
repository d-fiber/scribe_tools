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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/package/declares.dart';
import 'package:test/test.dart';

Matcher throwsToolExit(String saying) =>
    throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

void main() {
  const String where = 'foundation/lib/foundation.ts';

  group('declaresIn', () {
    test('a file with no declares export opens nothing', () {
      expect(declaresIn('export const scribe = {};\n', where), isEmpty);
    });

    test('one bucket reads the marker it names', () {
      expect(declaresIn('export const declares = { queues: Queue };\n', where), <String, String>{'queues': 'Queue'});
    });

    test('several buckets are all read, in the order they name nothing in particular', () {
      expect(declaresIn('export const declares = { queues: Queue, crons: Cron };\n', where), <String, String>{
        'queues': 'Queue',
        'crons': 'Cron',
      });
    });

    test('a block written across several lines reads the same as one line', () {
      const String source = 'export const declares = {\n  queues: Queue,\n  crons: Cron,\n};\n';

      expect(declaresIn(source, where), <String, String>{'queues': 'Queue', 'crons': 'Cron'});
    });

    test('a pair that is not bucket colon marker is refused', () {
      expect(() => declaresIn('export const declares = { queues };\n', where), throwsToolExit('not "bucket: Marker"'));
    });

    test('a bucket that is not an identifier is refused', () {
      expect(
        () => declaresIn('export const declares = { "my queues": Queue };\n', where),
        throwsToolExit('not a name a source file could spell'),
      );
    });

    test('a marker that is not an identifier is refused', () {
      expect(
        () => declaresIn('export const declares = { queues: "Queue" };\n', where),
        throwsToolExit('not a name a source file could spell'),
      );
    });

    test('one export opening the same bucket twice is refused', () {
      expect(
        () => declaresIn('export const declares = { queues: Queue, queues: Cron };\n', where),
        throwsToolExit('opens "queues" twice'),
      );
    });
  });

  group('readDeclares', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('a package with no entry opens nothing rather than failing', () {
      expect(readDeclares(root.path, 'foundation'), isEmpty);
    });

    test('a package reads the declares its entry, and only its entry, exports', () {
      File(p.join(root.path, 'lib', 'foundation.ts'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('export const declares = { queues: Queue };\n');

      expect(readDeclares(root.path, 'foundation'), <String, String>{'queues': 'Queue'});
    });

    test('an entry with no declares export opens nothing', () {
      File(p.join(root.path, 'lib', 'foundation.ts'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('export const scribe = {};\n');

      expect(readDeclares(root.path, 'foundation'), isEmpty);
    });
  });
}
