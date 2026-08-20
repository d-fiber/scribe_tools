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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/template.dart';
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
      expect(renderTemplate('t', '  {{block}}\n', <String, String>{'block': 'a\n\nb'}), '  a\n\n  b\n');
    });

    test('a placeholder sharing its line is substituted without indentation', () {
      expect(renderTemplate('t', 'key: {{block}}\n', <String, String>{'block': 'a\nb'}), 'key: a\nb\n');
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
          isA<ToolExit>().having((ToolExit e) => e.message, 'message', 'kong.yml: 2 unresolved variable(s): a, b'),
        ),
      );
    });

    test('a template without placeholder is returned verbatim', () {
      const String source = 'services:\n  api:\n    image: "deno"\n';
      expect(renderTemplate('t', source, const <String, String>{}), source);
    });
  });
}
