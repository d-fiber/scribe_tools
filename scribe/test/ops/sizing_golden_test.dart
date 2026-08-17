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

import 'dart:convert';
import 'dart:io';

import 'package:scribe/src/ops/hardware.dart';
import 'package:scribe/src/ops/sizing_rules.dart';
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
    golden =
        jsonDecode(File('test/ops/fixtures/sizing_golden.json').readAsStringSync()) as Map<String, dynamic>;
  });

  group('sizing a project that mounts every module', () {
    // The golden is the whole placeholder table, on six machine shapes. It is
    // not derived from anything: it is a photograph, kept so that a weight or a
    // formula edited by accident shows up as a number that moved. Replacing it
    // is a deliberate act, and it was last replaced by the renormalisation.
    for (final MapEntry<String, Hardware> shape in _shapes.entries) {
      test('resolves ${shape.key} to the values the golden holds', () {
        expect(SizingRules(shape.value, frameworkCapacity()).resolve(), golden[shape.key]);
      });
    }

    test('covers every shape the golden holds', () {
      expect(_shapes.keys.toSet(), golden.keys.toSet(), reason: 'a shape that is never replayed proves nothing');
    });
  });
}
