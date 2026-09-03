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

import 'package:scribe_tools/src/ops/prune.dart';
import 'package:test/test.dart';

const String _document = '''
name: "notes"

services:
  db:
    image: "postgres:15"
    volumes:
      - "db-data:/var/lib/postgresql/data"

  redis:
    image: "valkey:8"

  api:
    image: "denoland/deno:2.7.14"
    depends_on:
      db:
        condition: "service_healthy"
      redis:
        condition: "service_healthy"
      nats:
        condition: "service_started"

  rest:
    image: "postgrest:12"
    depends_on:
      db:
        condition: "service_healthy"

volumes:
  db-data: null
''';

void main() {
  group('an assembled document', () {
    test('comes back character for character when nothing left the stack', () {
      expect(withoutServices(_document, const <String>{}), _document);
    });

    test('loses the service that is not there any more, and nothing around it', () {
      final String pruned = withoutServices(_document, const <String>{'db'});

      expect(pruned, isNot(contains('postgres:15')));
      expect(pruned, contains('valkey:8'));
      expect(pruned, contains('  api:'));
      expect(pruned, contains('volumes:\n  db-data: null'));
    });

    test('loses every dependency on a service that left, and keeps the others', () {
      final String pruned = withoutServices(_document, const <String>{'db'});

      expect(pruned, contains('    depends_on:\n      redis:\n        condition: "service_healthy"'));
      expect(pruned, isNot(contains('      db:')));
    });

    test('loses the depends_on itself when every one of its entries left', () {
      final String pruned = withoutServices(_document, const <String>{'db', 'redis', 'nats'});

      expect(pruned, isNot(contains('depends_on')));
      expect(pruned, contains('  api:'));
      expect(pruned, contains('postgrest:12'));
    });

    test('leaves a service alone when only a service of another name left', () {
      expect(withoutServices(_document, const <String>{'opensearch'}), _document);
    });

    test('takes several services out at once', () {
      final String pruned = withoutServices(_document, const <String>{'db', 'rest'});

      expect(pruned, isNot(contains('postgres:15')));
      expect(pruned, isNot(contains('postgrest:12')));
      expect(pruned, contains('valkey:8'));
      expect(pruned, contains('  api:'));
    });
  });
}
