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

import 'package:scribe_tools/src/package/import_fold.dart';
import 'package:test/test.dart';

void main() {
  test('two packages answering different specifiers fold without a conflict', () {
    final ImportFold fold = foldImports(<PackageImports>[
      const PackageImports(name: 'auth', reaches: <String, String>{'@scribe/auth': 'file:///auth/mod.ts'}),
      const PackageImports(name: 'storage', reaches: <String, String>{'@scribe/storage': 'file:///storage/mod.ts'}),
    ]);

    expect(fold.imports, <String, String>{
      '@scribe/auth': 'file:///auth/mod.ts',
      '@scribe/storage': 'file:///storage/mod.ts',
    });
    expect(fold.conflicts, isEmpty);
  });

  test('a specifier answered two ways keeps the first and reports the second', () {
    final ImportFold fold = foldImports(<PackageImports>[
      const PackageImports(name: 'auth', reaches: <String, String>{'@scribe/alchemy': 'file:///one/mod.ts'}),
      const PackageImports(name: 'storage', reaches: <String, String>{'@scribe/alchemy': 'file:///two/mod.ts'}),
    ]);

    expect(fold.imports, <String, String>{'@scribe/alchemy': 'file:///one/mod.ts'});
    expect(fold.conflicts, hasLength(1));
    expect(fold.conflicts.single.specifier, '@scribe/alchemy');
    expect(fold.conflicts.single.kept, 'file:///one/mod.ts');
    expect(fold.conflicts.single.dropped, 'file:///two/mod.ts');
    expect(fold.conflicts.single.by, 'storage');
  });

  test('the map is folded with its keys sorted', () {
    final ImportFold fold = foldImports(<PackageImports>[
      const PackageImports(
        name: 'only',
        reaches: <String, String>{'@scribe/storage': 'file:///storage/mod.ts', '@scribe/auth': 'file:///auth/mod.ts'},
      ),
    ]);

    expect(fold.imports.keys.toList(), <String>['@scribe/auth', '@scribe/storage']);
  });

  test('an empty contribution folds in without adding anything', () {
    final ImportFold fold = foldImports(<PackageImports>[
      const PackageImports(name: 'auth', reaches: <String, String>{'@scribe/auth': 'file:///auth/mod.ts'}),
      const PackageImports(name: 'unresolved', reaches: <String, String>{}),
    ]);

    expect(fold.imports, <String, String>{'@scribe/auth': 'file:///auth/mod.ts'});
    expect(fold.conflicts, isEmpty);
  });
}
