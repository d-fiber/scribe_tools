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

import 'dart:convert';
import 'dart:io';

import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing_rules.dart';
import 'package:test/test.dart';

import 'capacity_source.dart';

/// The shapes the golden was taken on, and the labels it keys them by.
const Map<String, Hardware> _shapes = <String, Hardware>{
  '1c2t2g': Hardware(cores: 1, threads: 2, memoryGb: 2),
  '2c4t4g': Hardware(cores: 2, threads: 4, memoryGb: 4),
  '4c8t8g': Hardware(cores: 4, threads: 8, memoryGb: 8),
  '8c16t32g': Hardware(cores: 8, threads: 16, memoryGb: 32),
  '16c32t64g': Hardware(cores: 16, threads: 32, memoryGb: 64),
  '64c128t512g': Hardware(cores: 64, threads: 128, memoryGb: 512),
};

void main() {
  late Map<String, dynamic> golden;

  setUpAll(() {
    golden = jsonDecode(File('test/ops/fixtures/sizing_golden.json').readAsStringSync()) as Map<String, dynamic>;
  });

  group('sizing a project that mounts every package', () {
    for (final MapEntry<String, Hardware> shape in _shapes.entries) {
      test('resolves ${shape.key} to the values the golden holds', () {
        expect(
          SizingRules(shape.value, frameworkCapacity()).resolve(),
          golden[shape.key],
          reason: 'the golden is a photograph of the whole table, so replacing it has to be deliberate',
        );
      });
    }

    test('covers every shape the golden holds', () {
      expect(_shapes.keys.toSet(), golden.keys.toSet(), reason: 'a shape that is never replayed proves nothing');
    });
  });
}
