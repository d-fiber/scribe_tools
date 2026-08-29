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
import 'package:scribe_tools/src/package/imports.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
  tearDown(() => root.deleteSync(recursive: true));

  void source(String relative, String content) => File(p.join(root.path, relative))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  test('a directory that does not exist names nothing', () {
    expect(externalSpecifiersIn(p.join(root.path, 'gone')), isEmpty);
  });

  test('a named import is read for its specifier', () {
    source('a.ts', 'import { encode } from "blurhash";\n');

    expect(externalSpecifiersIn(root.path), <String>{'blurhash'});
  });

  test('a default import is read the same as a named one', () {
    source('a.ts', 'import decodeWebp from "@jsquash/webp/decode";\n');

    expect(externalSpecifiersIn(root.path), <String>{'@jsquash/webp/decode'});
  });

  test('a namespace import is read the same way', () {
    source('a.ts', 'import * as croner from "croner";\n');

    expect(externalSpecifiersIn(root.path), <String>{'croner'});
  });

  test('a re-export is read the same way an import is', () {
    source('a.ts', 'export { decode } from "fast-png";\n');

    expect(externalSpecifiersIn(root.path), <String>{'fast-png'});
  });

  test('a type-only import still carries its specifier, since the specifier is all that is read', () {
    source('a.ts', 'import type { FakePostgrestSeed } from "@supabase/postgrest-js";\n');

    expect(externalSpecifiersIn(root.path), <String>{'@supabase/postgrest-js'});
  });

  test('a side effect import with no from is read too', () {
    source('a.ts', 'import "left-pad";\n');

    expect(externalSpecifiersIn(root.path), <String>{'left-pad'});
  });

  test('a dynamic import is read wherever it sits in an expression', () {
    source('a.ts', 'const mod = await import("ioredis");\n');

    expect(externalSpecifiersIn(root.path), <String>{'ioredis'});
  });

  test('a multi-line named import is one match, and the brace block crossing lines is not confused for prose', () {
    source('a.ts', 'import {\n  Duration,\n  Queue,\n} from "@scribe/foundation";\n');

    expect(externalSpecifiersIn(root.path), isEmpty, reason: '@scribe/ specifiers are never external');
  });

  test('the word "from" inside a test name is never read as an import', () {
    source(
      'a.ts',
      'Deno.test("a read row lands under the declared field names, whatever column it came from", () => {\n'
          '  const compiled = compileDocument("stores", "store_id", {});\n'
          '});\n',
    );

    expect(externalSpecifiersIn(root.path), isEmpty);
  });

  test('a relative specifier names a file of the same package, not something external', () {
    source('a.ts', 'import { Storage } from "../storage.ts";\nimport { Table } from "./tables.ts";\n');

    expect(externalSpecifiersIn(root.path), isEmpty);
  });

  test('a specifier starting with @scribe/ is never external, package or framework surface alike', () {
    source(
      'a.ts',
      'import { Bytes } from "@scribe/alchemy";\n'
          'import { Table } from "@scribe/foundation/database";\n'
          'import { capabilities } from "@scribe/contracts/capability.ts";\n',
    );

    expect(externalSpecifiersIn(root.path), isEmpty);
  });

  test('every file under the directory is read, several levels deep', () {
    source('src/media/decode.ts', 'import { decode } from "jpeg-js";\n');
    source('src/media/encode.ts', 'import { encode } from "jpeg-js";\n');

    expect(externalSpecifiersIn(root.path), <String>{'jpeg-js'});
  });

  test('node_modules and hidden directories are never walked', () {
    source('node_modules/vendor/index.ts', 'import "left-pad";\n');
    source('.cache/index.ts', 'import "left-pad";\n');

    expect(externalSpecifiersIn(root.path), isEmpty);
  });

  test('a file that is not TypeScript is not read', () {
    source('notes.md', 'import "left-pad";\n');

    expect(externalSpecifiersIn(root.path), isEmpty);
  });

  test('several files each name their own specifier, and both are kept', () {
    source('a.ts', 'import "blurhash";\n');
    source('b.ts', 'import "croner";\n');

    expect(externalSpecifiersIn(root.path), <String>{'blurhash', 'croner'});
  });
}
