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

import 'package:scribe_tools/src/version.dart';
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
