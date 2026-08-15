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

import 'package:sdk/core/template/merge.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const String _base = '''
name: "{{app_name_snake}}"
services:
  db:
    image: "postgres"
networks:
  default:
    ipam: {}
''';

void main() {
  group('the fragment assembly', () {
    test('appends a fragment section under the section of the base', () {
      final String merged = mergeYamlDocuments(_base, <YamlFragment>[
        const YamlFragment('database/realtime', 'services:\n  realtime:\n    image: "realtime"\n'),
      ]);

      final YamlMap services = (loadYaml(merged) as YamlMap)['services'] as YamlMap;
      expect(services.keys, <String>['db', 'realtime']);
      expect(merged, contains('# database/realtime'));
    });

    test('keeps the sections of the base in their order, fragment or not', () {
      final String merged = mergeYamlDocuments(_base, <YamlFragment>[
        const YamlFragment('m', 'services:\n  a:\n    image: "a"\n'),
      ]);

      expect((loadYaml(merged) as YamlMap).keys, <String>['name', 'services', 'networks']);
    });

    test('adds a section the base does not declare', () {
      final String merged = mergeYamlDocuments(_base, <YamlFragment>[
        const YamlFragment('m', 'volumes:\n  cache: null\n'),
      ]);

      expect(((loadYaml(merged) as YamlMap)['volumes'] as YamlMap).keys, <String>['cache']);
    });

    test('drops the leading comments of a fragment, keeps those of the base', () {
      final String merged = mergeYamlDocuments('# socle\n$_base', <YamlFragment>[
        const YamlFragment('m', '# la doc du fragment\nservices:\n  a:\n    image: "a"\n'),
      ]);

      expect(merged, contains('# socle'));
      expect(merged, isNot(contains('la doc du fragment')));
    });

    test('leaves the base untouched when no fragment is mounted', () {
      expect(mergeYamlDocuments(_base, <YamlFragment>[]), _base);
    });

    test('merges several fragments into the same section', () {
      final String merged = mergeYamlDocuments(_base, <YamlFragment>[
        const YamlFragment('one', 'services:\n  a:\n    image: "a"\n'),
        const YamlFragment('two', 'services:\n  b:\n    image: "b"\n'),
      ]);

      expect(((loadYaml(merged) as YamlMap)['services'] as YamlMap).keys, <String>['db', 'a', 'b']);
    });
  });
}
