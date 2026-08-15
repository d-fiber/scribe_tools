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

import 'package:scribe/core/exception.dart';
import 'package:scribe/core/template/render.dart';
import 'package:test/test.dart';

void main() {
  group('renderTemplate', () {
    test('substitutes an inline placeholder', () {
      expect(renderTemplate('t', 'name: {{app}}', <String, String>{'app': 'poppin'}), 'name: poppin');
    });

    test('indents every line of a block placeholder to the placeholder column', () {
      const String template = 'consumers:\n  {{block}}\nacls: []\n';
      const String value = '- username: app\n  keyauth_credentials:\n    - key: abc';

      expect(
        renderTemplate('t', template, <String, String>{'block': value}),
        'consumers:\n'
        '  - username: app\n'
        '    keyauth_credentials:\n'
        '      - key: abc\n'
        'acls: []\n',
      );
    });

    test('leaves blank lines of a block unindented', () {
      expect(
        renderTemplate('t', '  {{block}}\n', <String, String>{'block': 'a\n\nb'}),
        '  a\n\n  b\n',
      );
    });

    test('a placeholder sharing its line is substituted without indentation', () {
      expect(
        renderTemplate('t', 'key: {{block}}\n', <String, String>{'block': 'a\nb'}),
        'key: a\nb\n',
      );
    });

    test('the same placeholder can appear at several columns', () {
      expect(
        renderTemplate('t', '  {{b}}\n      {{b}}\n', <String, String>{'b': 'x\ny'}),
        '  x\n  y\n      x\n      y\n',
      );
    });

    test('an unresolved placeholder fails, and names every missing key once', () {
      expect(
        () => renderTemplate('kong.yml', '{{a}}\n{{b}}\n{{a}}', const <String, String>{}),
        throwsA(
          isA<CliException>().having(
            (CliException e) => e.message,
            'message',
            'kong.yml: 2 unresolved variable(s) — a, b',
          ),
        ),
      );
    });

    test('a template without placeholder is returned verbatim', () {
      const String source = 'services:\n  api:\n    image: "deno"\n';
      expect(renderTemplate('t', source, const <String, String>{}), source);
    });
  });
}
