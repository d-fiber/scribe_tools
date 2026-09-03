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
import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';
import 'package:scribe_tools/src/forge/sql/emit_sql.dart';
import 'package:test/test.dart';

const SqlColumnType _uuid = SqlColumnType(kind: 'uuid');

DeclaredSqlColumn _column({bool primaryKey = false}) =>
    DeclaredSqlColumn(type: _uuid, notNull: true, primaryKey: primaryKey, unique: false);

DeclaredSqlSchema _schemaOf(DeclaredSqlTable table) => DeclaredSqlSchema(
  enums: const <DeclaredSqlEnum>[],
  compositeTypes: const <DeclaredSqlCompositeType>[],
  tables: <DeclaredSqlTable>[table],
  functions: const <DeclaredSqlFunction>[],
  triggers: const <DeclaredSqlTrigger>[],
  cronJobs: const <DeclaredSqlCronJob>[],
);

void main() {
  test('a single primary key column is emitted as one', () {
    final DeclaredSqlTable table = DeclaredSqlTable(
      name: 'widgets',
      columns: <String, DeclaredSqlColumn>{'id': _column(primaryKey: true), 'name': _column()},
    );

    final String sql = emitSql(packageName: 'pkg', schema: _schemaOf(table));

    expect(sql, contains('id uuid primary key'));
    expect(sql, isNot(contains('name uuid primary key')));
  });

  test('two primary key columns on the same table are refused before anything is emitted', () {
    final DeclaredSqlTable table = DeclaredSqlTable(
      name: 'widgets',
      columns: <String, DeclaredSqlColumn>{'a': _column(primaryKey: true), 'b': _column(primaryKey: true)},
    );

    expect(
      () => emitSql(packageName: 'pkg', schema: _schemaOf(table)),
      throwsA(
        isA<ToolExit>().having(
          (ToolExit error) => error.message,
          'message',
          allOf(contains('widgets'), contains('a'), contains('b')),
        ),
      ),
    );
  });
}
