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

import 'package:scribe_tools/src/self/version.dart';
import 'package:test/test.dart';

void main() {
  group('what reads as a version', () {
    test('three numbers, with the newline the file ends on', () {
      expect(Version.tryParse('0.1.5\n').toString(), '0.1.5');
      expect(Version.tryParse('  10.20.30  ').toString(), '10.20.30');
    });

    test('anything else is not one', () {
      for (final String raw in <String>['', '1', '1.2', '1.2.3.4', 'v1.2.3', '1.2.x', '1.-2.3', '1.2.3-rc1']) {
        expect(Version.tryParse(raw), isNull, reason: '"$raw" should not read as a version');
      }
    });
  });

  group('which one comes first', () {
    test('each number is compared before the one after it', () {
      expect(const Version(1, 0, 0).isNewerThan(const Version(0, 9, 9)), isTrue);
      expect(const Version(0, 2, 0).isNewerThan(const Version(0, 1, 9)), isTrue);
      expect(const Version(0, 1, 6).isNewerThan(const Version(0, 1, 5)), isTrue);
    });

    test('numbers are compared as numbers, not as text', () {
      expect(const Version(0, 10, 0).isNewerThan(const Version(0, 9, 0)), isTrue);
      expect(const Version(0, 1, 10).isNewerThan(const Version(0, 1, 9)), isTrue);
    });

    test('the same version is neither newer nor older, and equals itself', () {
      expect(const Version(0, 1, 5).isNewerThan(const Version(0, 1, 5)), isFalse);
      expect(const Version(0, 1, 5) == const Version(0, 1, 5), isTrue);
      expect(const Version(0, 1, 5).hashCode, const Version(0, 1, 5).hashCode);
    });

    test('a list of them sorts oldest first', () {
      final List<Version> versions = <Version>[
        const Version(0, 2, 0),
        const Version(0, 1, 10),
        const Version(1, 0, 0),
        const Version(0, 1, 9),
      ]..sort();

      expect(versions.map((Version version) => '$version').toList(), <String>['0.1.9', '0.1.10', '0.2.0', '1.0.0']);
    });
  });
}
