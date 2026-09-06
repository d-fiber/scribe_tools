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
const DeclaredSqlMoment _empty = DeclaredSqlMoment(
  tables: <DeclaredSqlTable>[],
  indexes: <DeclaredSqlIndex>[],
  policies: <DeclaredSqlPolicy>[],
  grants: <DeclaredSqlGrant>[],
  sequences: <DeclaredSqlSequence>[],
  enums: <DeclaredSqlEnum>[],
  compositeTypes: <DeclaredSqlCompositeType>[],
  extensions: <DeclaredSqlExtension>[],
  drops: <DeclaredSqlDrop>[],
);

DeclaredSqlColumn _column({bool primaryKey = false}) =>
    DeclaredSqlColumn(type: _uuid, notNull: true, primaryKey: primaryKey, unique: false);

DeclaredSqlTable _table({
  required String name,
  Map<String, DeclaredSqlColumn> columns = const <String, DeclaredSqlColumn>{},
  bool rowLevelSecurity = false,
  List<DeclaredSqlRevoke> revokes = const <DeclaredSqlRevoke>[],
}) => DeclaredSqlTable(name: name, columns: columns, rowLevelSecurity: rowLevelSecurity, revokes: revokes);

/// A schema whose `init` moment carries whatever is given, everything else empty.
DeclaredSqlSchema _initSchemaOf({
  List<DeclaredSqlEnum> enums = const <DeclaredSqlEnum>[],
  List<DeclaredSqlCompositeType> compositeTypes = const <DeclaredSqlCompositeType>[],
  List<DeclaredSqlTable> tables = const <DeclaredSqlTable>[],
  List<DeclaredSqlIndex> indexes = const <DeclaredSqlIndex>[],
  List<DeclaredSqlPolicy> policies = const <DeclaredSqlPolicy>[],
  List<DeclaredSqlGrant> grants = const <DeclaredSqlGrant>[],
  List<DeclaredSqlSequence> sequences = const <DeclaredSqlSequence>[],
  List<DeclaredSqlExtension> extensions = const <DeclaredSqlExtension>[],
}) => DeclaredSqlSchema(
  init: DeclaredSqlMoment(
    tables: tables,
    indexes: indexes,
    policies: policies,
    grants: grants,
    sequences: sequences,
    enums: enums,
    compositeTypes: compositeTypes,
    extensions: extensions,
    drops: const <DeclaredSqlDrop>[],
  ),
  migrations: _empty,
  provisioning: _empty,
);

/// A schema whose `migrations` moment carries [drops] and [enums], everything else empty.
DeclaredSqlSchema _migrationsSchemaOf({
  List<DeclaredSqlDrop> drops = const <DeclaredSqlDrop>[],
  List<DeclaredSqlEnum> enums = const <DeclaredSqlEnum>[],
}) => DeclaredSqlSchema(
  init: _empty,
  migrations: DeclaredSqlMoment(
    tables: const <DeclaredSqlTable>[],
    indexes: const <DeclaredSqlIndex>[],
    policies: const <DeclaredSqlPolicy>[],
    grants: const <DeclaredSqlGrant>[],
    sequences: const <DeclaredSqlSequence>[],
    enums: enums,
    compositeTypes: const <DeclaredSqlCompositeType>[],
    extensions: const <DeclaredSqlExtension>[],
    drops: drops,
  ),
  provisioning: _empty,
);

/// A schema whose `provisioning` moment carries [extensions] and [drops], everything else empty.
DeclaredSqlSchema _provisioningSchemaOf({
  List<DeclaredSqlExtension> extensions = const <DeclaredSqlExtension>[],
  List<DeclaredSqlDrop> drops = const <DeclaredSqlDrop>[],
}) => DeclaredSqlSchema(
  init: _empty,
  migrations: _empty,
  provisioning: DeclaredSqlMoment(
    tables: const <DeclaredSqlTable>[],
    indexes: const <DeclaredSqlIndex>[],
    policies: const <DeclaredSqlPolicy>[],
    grants: const <DeclaredSqlGrant>[],
    sequences: const <DeclaredSqlSequence>[],
    enums: const <DeclaredSqlEnum>[],
    compositeTypes: const <DeclaredSqlCompositeType>[],
    extensions: extensions,
    drops: drops,
  ),
);

void main() {
  test('a single primary key column is emitted as one', () {
    final DeclaredSqlTable table = _table(
      name: 'widgets',
      columns: <String, DeclaredSqlColumn>{'id': _column(primaryKey: true), 'name': _column()},
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
    ).init!;

    expect(sql, contains('id uuid primary key'));
    expect(sql, isNot(contains('name uuid primary key')));
  });

  test('two primary key columns on the same table are refused before anything is emitted', () {
    final DeclaredSqlTable table = _table(
      name: 'widgets',
      columns: <String, DeclaredSqlColumn>{'a': _column(primaryKey: true), 'b': _column(primaryKey: true)},
    );

    expect(
      () => emitSql(
        packageName: 'pkg',
        schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
      ),
      throwsA(
        isA<ToolExit>().having(
          (ToolExit error) => error.message,
          'message',
          allOf(contains('widgets'), contains('a'), contains('b')),
        ),
      ),
    );
  });

  test('a plain index names its table and columns, with no access method or predicate', () {
    final DeclaredSqlTable table = _table(name: 'widgets');
    const DeclaredSqlIndex index = DeclaredSqlIndex(
      name: 'widgets_owner_idx',
      options: SqlIndexOptions(table: 'widgets', columns: <String>['owner'], unique: false),
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table], indexes: <DeclaredSqlIndex>[index]),
    ).init!;

    expect(sql, contains('create index if not exists widgets_owner_idx on pkg.widgets (owner);'));
  });

  test('a unique index using a chosen access method, restricted by a predicate', () {
    final DeclaredSqlTable table = _table(name: 'widgets');
    const DeclaredSqlIndex index = DeclaredSqlIndex(
      name: 'widgets_label_idx',
      options: SqlIndexOptions(
        table: 'widgets',
        columns: <String>['lower(label)'],
        unique: true,
        using: 'gin',
        where: 'label is not null',
      ),
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table], indexes: <DeclaredSqlIndex>[index]),
    ).init!;

    expect(
      sql,
      contains(
        'create unique index if not exists widgets_label_idx on pkg.widgets using gin (lower(label)) '
        'where label is not null;',
      ),
    );
  });

  test('a policy is dropped before it is recreated, since Postgres has no create policy if not exists', () {
    const DeclaredSqlPolicy policy = DeclaredSqlPolicy(
      name: 'widgets_self',
      options: SqlPolicyOptions(table: 'widgets', command: 'select', to: <String>['authenticated'], using: 'true'),
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(policies: <DeclaredSqlPolicy>[policy]),
    ).init!;

    expect(sql, contains('drop policy if exists widgets_self on pkg.widgets;'));
    expect(sql, contains('create policy widgets_self on pkg.widgets for select to authenticated using (true);'));
  });

  test('a grant naming "all" privileges renders as "all privileges", not a literal list', () {
    const DeclaredSqlGrant grant = DeclaredSqlGrant(
      options: SqlGrantOptions(
        privileges: null,
        on: SqlGrantObject(kind: 'table', name: 'widgets'),
        to: <String>['service_role'],
        withGrantOption: true,
      ),
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(grants: <DeclaredSqlGrant>[grant]),
    ).init!;

    expect(sql, contains('grant all privileges on table pkg.widgets to service_role with grant option;'));
  });

  test('the migrations moment is wrapped in the migrate:up/migrate:down sections dbmate requires', () {
    final DeclaredSqlTable table = _table(name: 'widgets');
    final DeclaredSqlSchema schema = DeclaredSqlSchema(
      init: _empty,
      migrations: DeclaredSqlMoment(
        tables: <DeclaredSqlTable>[table],
        indexes: <DeclaredSqlIndex>[],
        policies: <DeclaredSqlPolicy>[],
        grants: <DeclaredSqlGrant>[],
        sequences: <DeclaredSqlSequence>[],
        enums: <DeclaredSqlEnum>[],
        compositeTypes: <DeclaredSqlCompositeType>[],
        extensions: <DeclaredSqlExtension>[],
        drops: <DeclaredSqlDrop>[],
      ),
      provisioning: _empty,
    );

    final EmittedSql emitted = emitSql(packageName: 'pkg', schema: schema);

    expect(emitted.init, isNull);
    expect(emitted.migrations, startsWith('-- migrate:up transaction:false\n'));
    expect(emitted.migrations, contains('-- migrate:down transaction:false\n'));
    expect(emitted.migrations, contains('create table if not exists pkg.widgets'));
  });

  test('an enum has no create if not exists, so it is wrapped in a to_regtype check instead', () {
    const DeclaredSqlEnum status = DeclaredSqlEnum(name: 'status', values: <String>['pending', 'done']);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(enums: <DeclaredSqlEnum>[status]),
    ).init!;

    expect(sql, contains('do \$\$ begin'));
    expect(sql, contains("if to_regtype('pkg.status') is null then"));
    expect(sql, contains('create type pkg.status as enum'));
    expect(sql, contains('end \$\$;'));
  });

  test('a composite type has no create if not exists, so it is wrapped in a to_regtype check instead', () {
    const DeclaredSqlCompositeType point = DeclaredSqlCompositeType(
      name: 'point',
      fields: <String, SqlColumnType>{
        'x': SqlColumnType(kind: 'integer'),
        'y': SqlColumnType(kind: 'integer'),
      },
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(compositeTypes: <DeclaredSqlCompositeType>[point]),
    ).init!;

    expect(sql, contains('do \$\$ begin'));
    expect(sql, contains("if to_regtype('pkg.point') is null then"));
    expect(sql, contains('create type pkg.point as'));
    expect(sql, contains('end \$\$;'));
  });

  test('a sequence with no option set renders as a bare create sequence if not exists', () {
    const DeclaredSqlSequence sequence = DeclaredSqlSequence(name: 'widgets_seq', cycle: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(sequences: <DeclaredSqlSequence>[sequence]),
    ).init!;

    expect(sql, contains('create sequence if not exists pkg.widgets_seq;\n'));
  });

  test('a sequence with every option set, owned by a column', () {
    const DeclaredSqlSequence sequence = DeclaredSqlSequence(
      name: 'widgets_seq',
      as: 'int4',
      incrementBy: 2,
      minValue: 'none',
      maxValue: 1000,
      startWith: 5,
      cache: 10,
      cycle: true,
      ownedBy: SqlSequenceOwner(table: 'widgets', column: 'id'),
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(sequences: <DeclaredSqlSequence>[sequence]),
    ).init!;

    expect(sql, contains('as int4'));
    expect(sql, contains('increment by 2'));
    expect(sql, contains('no minvalue'));
    expect(sql, contains('maxvalue 1000'));
    expect(sql, contains('start with 5'));
    expect(sql, contains('cache 10'));
    expect(sql, contains('cycle'));
    expect(sql, contains('owned by pkg.widgets.id'));
  });

  test('an extension installs with if not exists, its name double-quoted', () {
    const DeclaredSqlExtension extension = DeclaredSqlExtension(name: 'uuid-ossp', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _provisioningSchemaOf(extensions: <DeclaredSqlExtension>[extension]),
    ).provisioning!;

    expect(sql, contains('create extension if not exists "uuid-ossp";'));
  });

  test('an extension names its schema and version, and cascades to its own dependencies', () {
    const DeclaredSqlExtension extension = DeclaredSqlExtension(
      name: 'hstore',
      schema: 'public',
      version: '1.4',
      cascade: true,
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _provisioningSchemaOf(extensions: <DeclaredSqlExtension>[extension]),
    ).provisioning!;

    expect(sql, contains('create extension if not exists "hstore" schema public version \'1.4\' cascade;'));
  });

  test('a table retirement carries if exists, and cascade when asked', () {
    const DeclaredSqlDropTable drop = DeclaredSqlDropTable(name: 'legacy_sessions', cascade: true);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).migrations!;

    expect(sql, contains('drop table if exists pkg.legacy_sessions cascade;'));
  });

  test('an index retirement carries if exists', () {
    const DeclaredSqlDropIndex drop = DeclaredSqlDropIndex(name: 'legacy_sessions_token_idx', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).migrations!;

    expect(sql, contains('drop index if exists pkg.legacy_sessions_token_idx;'));
  });

  test('a type retirement carries if exists', () {
    const DeclaredSqlDropType drop = DeclaredSqlDropType(name: 'legacy_status', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).migrations!;

    expect(sql, contains('drop type if exists pkg.legacy_status;'));
  });

  test('an extension retirement is double-quoted', () {
    const DeclaredSqlDropExtension drop = DeclaredSqlDropExtension(name: 'hstore', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).migrations!;

    expect(sql, contains('drop extension if exists "hstore";'));
  });

  test('a policy retirement names the table it is dropped from', () {
    const DeclaredSqlDropPolicy drop = DeclaredSqlDropPolicy(
      name: 'bookings_self_read',
      table: 'bookings',
      cascade: false,
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).migrations!;

    expect(sql, contains('drop policy if exists bookings_self_read on pkg.bookings;'));
  });

  test('row-level security renders as an alter table right after the table it protects', () {
    final DeclaredSqlTable table = _table(name: 'widgets', rowLevelSecurity: true);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
    ).init!;

    expect(sql, contains('alter table pkg.widgets enable row level security;'));
  });

  test('a table that never asks for row-level security carries no alter table for it', () {
    final DeclaredSqlTable table = _table(name: 'widgets');

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
    ).init!;

    expect(sql, isNot(contains('enable row level security')));
  });

  test('revoking "all" renders as "all", not a literal list, and needs no if exists', () {
    final DeclaredSqlTable table = _table(
      name: 'widgets',
      revokes: <DeclaredSqlRevoke>[
        const DeclaredSqlRevoke(privileges: null, from: <String>['authenticated', 'anon']),
      ],
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
    ).init!;

    expect(sql, contains('revoke all on pkg.widgets from authenticated, anon;'));
  });

  test('revoking a named list of privileges lists them, not "all"', () {
    final DeclaredSqlTable table = _table(
      name: 'widgets',
      revokes: <DeclaredSqlRevoke>[
        const DeclaredSqlRevoke(privileges: <String>['insert', 'update', 'delete'], from: <String>['authenticated']),
      ],
    );

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(tables: <DeclaredSqlTable>[table]),
    ).init!;

    expect(sql, contains('revoke insert, update, delete on pkg.widgets from authenticated;'));
  });

  test('an extension batched under init renders there, not only under provisioning', () {
    const DeclaredSqlExtension extension = DeclaredSqlExtension(name: 'pg_trgm', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _initSchemaOf(extensions: <DeclaredSqlExtension>[extension]),
    ).init!;

    expect(sql, contains('create extension if not exists "pg_trgm";'));
  });

  test('a retirement batched under provisioning renders there, not only under migrations', () {
    const DeclaredSqlDropType drop = DeclaredSqlDropType(name: 'legacy_status', cascade: false);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _provisioningSchemaOf(drops: <DeclaredSqlDrop>[drop]),
    ).provisioning!;

    expect(sql, contains('drop type if exists pkg.legacy_status;'));
  });

  test('an enum batched under migrations renders there, not only under init', () {
    const DeclaredSqlEnum declaredEnum = DeclaredSqlEnum(name: 'legacy_status', values: <String>['open', 'closed']);

    final String sql = emitSql(
      packageName: 'pkg',
      schema: _migrationsSchemaOf(enums: <DeclaredSqlEnum>[declaredEnum]),
    ).migrations!;

    expect(sql, contains("if to_regtype('pkg.legacy_status') is null then"));
  });
}
