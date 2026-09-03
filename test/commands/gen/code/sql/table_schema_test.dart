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

import 'package:scribe_tools/src/commands/gen/code/sql/table_schema.dart';
import 'package:test/test.dart';

void main() {
  test('a column named unique, check or constraint is kept, not read as a table constraint', () {
    final List<Col> cols = parseColumns('''
      id uuid,
      unique boolean not null,
      check text,
      constraint text
    ''');

    expect(cols.map((Col col) => col.name), <String>['id', 'unique', 'check', 'constraint']);
  });

  test('a real table-level constraint is still skipped, not read as a column', () {
    final List<Col> cols = parseColumns('''
      id uuid,
      email text,
      primary key (id),
      unique (email),
      check (email <> ''),
      constraint fk_thing foreign key (id) references other(id)
    ''');

    expect(cols.map((Col col) => col.name), <String>['id', 'email']);
  });

  test('a multi-line table-level constraint is skipped in full', () {
    final List<Col> cols = parseColumns('''
      id uuid,
      check (
        id is not null
      )
    ''');

    expect(cols.map((Col col) => col.name), <String>['id']);
  });
}
