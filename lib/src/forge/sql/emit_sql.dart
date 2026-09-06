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

import 'dart:collection';

import 'package:change_case/change_case.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';

/// The SQL body for each of a package's three `db` moments that has anything to say.
///
/// A moment [DeclaredSqlMoment.isEmpty] answers null here rather than an empty string, so
/// `generate_package_sql.dart` can leave the file it would have gone under unwritten.
class EmittedSql {
  /// Holds the SQL body for each moment, null for one with nothing to say.
  const EmittedSql({required this.init, required this.migrations, required this.provisioning});

  /// The `init` moment's SQL.
  final String? init;

  /// The `migrations` moment's SQL, wrapped in the `-- migrate:up`/`-- migrate:down` sections
  /// `dbmate` requires — see this file's own remarks on [emitSql] for what that does and does not buy.
  final String? migrations;

  /// The `provisioning` moment's SQL.
  final String? provisioning;
}

/// The SQL that provisions [schema] into [packageName]'s own schema, one body per moment that has
/// anything to say.
///
/// Every table, type, enum, sequence and extension is qualified `<packageName>.<name>` — an
/// extension excepted, which installs into its own control file's schema, or [DeclaredSqlExtension.schema]
/// when given — and nothing here creates that schema: `run-provision.sh` does, once, before
/// playing a package's `deploy/db/init/` — the same division that keeps a package's SQL ignorant
/// of the roles the stack sets up around it.
///
/// A column's or a field's name is written in snake_case whatever case the object literal that
/// declared it used, since a TypeScript author reaches for camelCase by reflex and every hand
/// written column in this framework is snake_case. A table's, an enum's, a composite type's, an
/// index's, a policy's, a sequence's or an extension's own name is never touched: it is a string
/// an author already chose on purpose, not an object key.
///
/// Every declaration this renders is safe to replay: a table, an index, a sequence or an
/// extension takes Postgres's own `if not exists`; an enum or a composite type, neither of which
/// Postgres gives one to, is wrapped in a `do $$ ... end $$;` block that checks `to_regtype`
/// first; a policy is dropped before it is recreated, the only way to make it safe since Postgres
/// has no `create policy if not exists` either; switching on row-level security and revoking a
/// privilege are each already idempotent in Postgres itself, needing neither guard; a retirement —
/// what `Drop` declared — always carries `if exists` of its own. None of this is a choice a package
/// makes any more: `schema/` itself carries no `ifExists` to turn off, `schema.md`'s own `## Drop`
/// section gives the reason.
///
/// Within one moment: enums come first, then composite types, then tables ordered so a table
/// referenced by a foreign key is created before the table that carries it — each table's own
/// `alter table ... enable row level security` and its revocations render immediately after that
/// table's own `create table`, before the next table starts — then sequences, then indexes, then
/// policies, then grants, then extensions, then retirements last of all. Throws a [ToolExit] naming
/// the tables when two or more of them reference each other in a cycle, since no order would
/// satisfy every foreign key — this ordering, and that refusal, only ever look within one moment: a
/// foreign key spanning two different moments is not checked at all, `schema.md` gives the reason.
///
/// None of the four — an enum, a composite type, an extension, a retirement — carries a moment of
/// its own any more: which of a package's three files each renders into is entirely a fact about
/// which of `Schema`'s own batches, `dbSchema.init()`, `.migrations()` or `.provisioning()`, listed
/// it, `schema.md`'s own `## Schema` section gives the reason. Nothing here judges whether a given
/// placement makes sense — an extension batched under `init` renders there just the same as one
/// batched under `provisioning`.
///
/// [EmittedSql.migrations] is wrapped in `dbmate`'s own `-- migrate:up`/`-- migrate:down` markers,
/// without which the file is not valid input to it at all — but this buys only that much: `dbmate`
/// tracks a migration by its file name and runs each name once, ever, while `scribe forge` rewrites
/// this same file whole on every run. A table added to `migrations` after the first deployment
/// that already applied this file's old content is never applied to it: `dbmate` sees the same
/// name already recorded and skips it. Nothing here generates the timestamped, one-shot-per-change
/// file `dbmate` actually expects for that to work, so a package that changes what it declares for
/// `migrations` after its first deployment still has to carry the change by hand, the same as
/// before this existed.
///
/// The `down` section of every `migrations` body is left empty on purpose: a declarative dump of
/// what a moment creates has no reverse to offer without also declaring what to drop, and nothing
/// here attempts to infer one.
EmittedSql emitSql({required String packageName, required DeclaredSqlSchema schema}) {
  final String? init = _emitMoment(packageName, schema.init);
  final String? migrations = _emitMoment(packageName, schema.migrations);
  final String? provisioning = _emitMoment(packageName, schema.provisioning);

  return EmittedSql(
    init: init,
    migrations: migrations == null
        ? null
        : '-- migrate:up transaction:false\n$migrations\n-- migrate:down transaction:false\n',
    provisioning: provisioning,
  );
}

String? _emitMoment(String packageName, DeclaredSqlMoment moment) {
  if (moment.isEmpty) return null;

  final StringBuffer sql = StringBuffer();
  for (final DeclaredSqlEnum declaredEnum in moment.enums) {
    sql.writeln(_emitEnum(packageName, declaredEnum));
  }
  for (final DeclaredSqlCompositeType compositeType in moment.compositeTypes) {
    sql.writeln(_emitCompositeType(packageName, compositeType));
  }
  for (final DeclaredSqlTable table in _orderedTables(moment.tables)) {
    sql.writeln(_emitTable(packageName, table));
  }
  for (final DeclaredSqlSequence sequence in moment.sequences) {
    sql.writeln(_emitSequence(packageName, sequence));
  }
  for (final DeclaredSqlIndex index in moment.indexes) {
    sql.writeln(_emitIndex(packageName, index));
  }
  for (final DeclaredSqlPolicy policy in moment.policies) {
    sql.writeln(_emitPolicy(packageName, policy));
  }
  for (final DeclaredSqlGrant grant in moment.grants) {
    sql.writeln(_emitGrant(packageName, grant));
  }
  for (final DeclaredSqlExtension extension in moment.extensions) {
    sql.writeln(emitExtension(extension));
  }
  for (final DeclaredSqlDrop drop in moment.drops) {
    sql.writeln(emitDrop(packageName, drop));
  }

  return sql.toString();
}

/// Postgres has no `create type ... if not exists`, for an enum or a composite type alike: the
/// `do $$ ... end $$;` block checks `to_regtype`, which answers null for a name that resolves to
/// nothing rather than raising, before creating — the same idea as `create table if not exists`,
/// spelled the only way Postgres lets a type reach for it.
String _emitEnum(String packageName, DeclaredSqlEnum declaredEnum) {
  final String values = declaredEnum.values.map((String value) => "      '$value'").join(',\n');
  return 'do \$\$ begin\n'
      "  if to_regtype('$packageName.${declaredEnum.name}') is null then\n"
      '    create type $packageName.${declaredEnum.name} as enum (\n$values\n    );\n'
      '  end if;\n'
      'end \$\$;\n';
}

String _emitCompositeType(String packageName, DeclaredSqlCompositeType compositeType) {
  final String fields = compositeType.fields.entries
      .map(
        (MapEntry<String, SqlColumnType> field) =>
            '      ${field.key.toSnakeCase()} ${_sqlType(packageName, field.value)}',
      )
      .join(',\n');
  return 'do \$\$ begin\n'
      "  if to_regtype('$packageName.${compositeType.name}') is null then\n"
      '    create type $packageName.${compositeType.name} as (\n$fields\n    );\n'
      '  end if;\n'
      'end \$\$;\n';
}

/// A sequence that outlives a single column — the case a column's own `identity` already covers
/// with an implicit one — `owned by` tying its lifecycle to a column when [DeclaredSqlSequence.ownedBy]
/// names one, exactly the way an implicit sequence already is.
String _emitSequence(String packageName, DeclaredSqlSequence sequence) {
  final StringBuffer sql = StringBuffer('create sequence if not exists $packageName.${sequence.name}');
  if (sequence.as != null) sql.write('\n  as ${sequence.as}');
  if (sequence.incrementBy != null) sql.write('\n  increment by ${sequence.incrementBy}');
  switch (sequence.minValue) {
    case 'none':
      sql.write('\n  no minvalue');
    case final int value:
      sql.write('\n  minvalue $value');
  }
  switch (sequence.maxValue) {
    case 'none':
      sql.write('\n  no maxvalue');
    case final int value:
      sql.write('\n  maxvalue $value');
  }
  if (sequence.startWith != null) sql.write('\n  start with ${sequence.startWith}');
  if (sequence.cache != null) sql.write('\n  cache ${sequence.cache}');
  if (sequence.cycle) sql.write('\n  cycle');
  if (sequence.ownedBy case final SqlSequenceOwner owner) {
    sql.write('\n  owned by $packageName.${owner.table}.${owner.column}');
  }
  sql.write(';\n');
  return sql.toString();
}

/// An extension's name is double-quoted since Postgres refuses several of the ones a package
/// actually reaches for unquoted — `uuid-ossp`'s hyphen chief among them.
String emitExtension(DeclaredSqlExtension extension) {
  final StringBuffer sql = StringBuffer('create extension if not exists "${extension.name}"');
  if (extension.schema != null) sql.write(' schema ${extension.schema}');
  if (extension.version != null) sql.write(" version '${extension.version}'");
  if (extension.cascade) sql.write(' cascade');
  sql.write(';\n');
  return sql.toString();
}

/// What `Drop` declared, rendered as the one statement that retires it. Every kind already carries
/// its own `if exists`: a retirement that names an object already gone is exactly the ordinary
/// case `db.migrations` replays into, not a mistake to refuse.
String emitDrop(String packageName, DeclaredSqlDrop drop) {
  final String cascade = drop.cascade ? ' cascade' : '';

  return switch (drop) {
    DeclaredSqlDropTable() => 'drop table if exists $packageName.${drop.name}$cascade;\n',
    DeclaredSqlDropIndex() => 'drop index if exists $packageName.${drop.name}$cascade;\n',
    DeclaredSqlDropType() => 'drop type if exists $packageName.${drop.name}$cascade;\n',
    DeclaredSqlDropExtension() => 'drop extension if exists "${drop.name}"$cascade;\n',
    final DeclaredSqlDropPolicy policy =>
      'drop policy if exists ${policy.name} on $packageName.${policy.table}$cascade;\n',
  };
}

String _emitTable(String packageName, DeclaredSqlTable table) {
  final List<String> primaryKeys = <String>[
    for (final MapEntry<String, DeclaredSqlColumn> column in table.columns.entries)
      if (column.value.primaryKey) column.key,
  ];
  if (primaryKeys.length > 1) {
    throwToolExit(
      '${table.name} names a primary key on more than one column: ${primaryKeys.join(', ')}.\n'
      'A table has exactly one primary key: keep it on one column, and reach for a unique '
      'constraint on the others.',
    );
  }

  final String columns = table.columns.entries
      .map((MapEntry<String, DeclaredSqlColumn> column) => '  ${_emitColumn(packageName, column.key, column.value)}')
      .join(',\n');
  final StringBuffer sql = StringBuffer('create table if not exists $packageName.${table.name} (\n$columns\n);\n');

  if (table.rowLevelSecurity) {
    sql.writeln('alter table $packageName.${table.name} enable row level security;');
  }
  for (final DeclaredSqlRevoke revoke in table.revokes) {
    sql.writeln(_emitRevoke(packageName, table.name, revoke));
  }

  return sql.toString();
}

/// A `revoke` needs no `if exists`: Postgres already treats revoking a privilege nobody holds as an
/// idempotent no-op, the mirror of what `grant.ts`'s own remarks give as the reason `_emitGrant`
/// needs none either.
String _emitRevoke(String packageName, String tableName, DeclaredSqlRevoke revoke) {
  final String privileges = revoke.privileges == null ? 'all' : revoke.privileges!.join(', ');
  return 'revoke $privileges on $packageName.$tableName from ${revoke.from.join(', ')};\n';
}

String _emitColumn(String packageName, String name, DeclaredSqlColumn column) {
  final StringBuffer line = StringBuffer('${name.toSnakeCase()} ${_sqlType(packageName, column.type)}');

  if (column.primaryKey) {
    line.write(' primary key');
  } else if (column.notNull) {
    line.write(' not null');
  }
  if (column.unique) line.write(' unique');
  if (column.defaultSql != null) line.write(' default ${column.defaultSql}');
  if (column.references case final SqlColumnReference reference) {
    line.write(' references $packageName.${reference.table}(${reference.column})');
    if (reference.onDelete != null) line.write(' on delete ${_onDeleteSql(reference.onDelete!)}');
  }

  return line.toString();
}

String _emitIndex(String packageName, DeclaredSqlIndex index) {
  final SqlIndexOptions options = index.options;
  final StringBuffer sql = StringBuffer(
    options.unique ? 'create unique index if not exists ' : 'create index if not exists ',
  )..write('${index.name} on $packageName.${options.table}');
  if (options.using != null) sql.write(' using ${options.using}');
  sql.write(' (${options.columns.join(', ')})');
  if (options.where != null) sql.write(' where ${options.where}');
  sql.write(';\n');
  return sql.toString();
}

/// Postgres has no `create policy if not exists`: a policy is dropped first, the same idiom
/// `_emitTrigger` used to reach for before triggers themselves were dropped from `schema/`, and
/// still the only way to make a declarative policy dump safe to run more than once.
String _emitPolicy(String packageName, DeclaredSqlPolicy policy) {
  final SqlPolicyOptions options = policy.options;
  final StringBuffer sql = StringBuffer('drop policy if exists ${policy.name} on $packageName.${options.table};\n')
    ..write('create policy ${policy.name} on $packageName.${options.table}');
  if (options.kind != null) sql.write(' as ${options.kind}');
  sql.write(' for ${options.command ?? 'all'}');
  if (options.to case final List<String> to when to.isNotEmpty) sql.write(' to ${to.join(', ')}');
  if (options.using != null) sql.write(' using (${options.using})');
  if (options.withCheck != null) sql.write(' with check (${options.withCheck})');
  sql.write(';\n');
  return sql.toString();
}

/// A `grant` needs no `if not exists`: Postgres already treats granting the same privilege twice
/// as an idempotent no-op, `grant.ts`'s own remarks give the reason.
String _emitGrant(String packageName, DeclaredSqlGrant grant) {
  final SqlGrantOptions options = grant.options;
  final String privileges = options.privileges == null ? 'all privileges' : options.privileges!.join(', ');
  final StringBuffer sql = StringBuffer('grant $privileges on ${_grantObjectSql(packageName, options.on)} ')
    ..write('to ${options.to.join(', ')}');
  if (options.withGrantOption == true) sql.write(' with grant option');
  sql.write(';\n');
  return sql.toString();
}

String _grantObjectSql(String packageName, SqlGrantObject on) => switch (on.kind) {
  'table' => 'table $packageName.${on.name}',
  'sequence' => 'sequence $packageName.${on.name}',
  'schema' => 'schema ${on.name}',
  'function' => 'function $packageName.${on.name}',
  'type' => 'type $packageName.${on.name}',
  'domain' => 'domain $packageName.${on.name}',
  'database' => 'database ${on.name}',
  _ => throwToolExit('unknown grant object kind "${on.kind}", the schema bridge and this renderer have drifted apart.'),
};

String _onDeleteSql(String onDelete) => switch (onDelete) {
  'cascade' => 'cascade',
  'restrict' => 'restrict',
  'set null' => 'set null',
  _ => throwToolExit('unknown onDelete action "$onDelete", the schema bridge and this renderer have drifted apart.'),
};

String _sqlType(String packageName, SqlColumnType type) => switch (type.kind) {
  'uuid' => 'uuid',
  'text' => 'text',
  'varchar' => 'varchar(${type.length})',
  'bigint' => 'bigint',
  'integer' => 'integer',
  'boolean' => 'boolean',
  'timestamp' => 'timestamptz',
  'jsonb' => 'jsonb',
  'bigserial' => 'bigserial',
  'enum' => '$packageName.${type.name}',
  'composite' => '$packageName.${type.name}',
  'array' => '${_sqlType(packageName, type.of!)}[]',
  _ => throwToolExit(
    'column type "${type.kind}" has no renderer yet: this covers a smaller vocabulary than '
    '`ColumnType` accepts, and this kind is outside it.',
  ),
};

/// [tables], ordered so a table referenced by a foreign key comes before the table that carries it.
///
/// A reference to a table outside [tables] is left unconstrained: it names a table this run did
/// not declare, and that is either another file this package will also generate or a mistake the
/// database itself will refuse when the foreign key is created against nothing.
///
/// Throws a [ToolExit] naming every table caught in a cycle, since no order would satisfy every
/// foreign key at once.
List<DeclaredSqlTable> _orderedTables(List<DeclaredSqlTable> tables) {
  final Map<String, DeclaredSqlTable> byName = <String, DeclaredSqlTable>{
    for (final DeclaredSqlTable table in tables) table.name: table,
  };
  final Map<String, int> waitingOn = <String, int>{for (final DeclaredSqlTable table in tables) table.name: 0};
  final Map<String, List<String>> unlocks = <String, List<String>>{
    for (final DeclaredSqlTable table in tables) table.name: <String>[],
  };

  for (final DeclaredSqlTable table in tables) {
    for (final DeclaredSqlColumn column in table.columns.values) {
      final String? referenced = column.references?.table;
      if (referenced == null || referenced == table.name || !byName.containsKey(referenced)) continue;
      unlocks[referenced]!.add(table.name);
      waitingOn[table.name] = waitingOn[table.name]! + 1;
    }
  }

  final Queue<String> ready = Queue<String>.of(
    tables.map((DeclaredSqlTable table) => table.name).where((String name) => waitingOn[name] == 0),
  );
  final List<DeclaredSqlTable> ordered = <DeclaredSqlTable>[];

  while (ready.isNotEmpty) {
    final String name = ready.removeFirst();
    ordered.add(byName[name]!);
    for (final String dependent in unlocks[name]!) {
      waitingOn[dependent] = waitingOn[dependent]! - 1;
      if (waitingOn[dependent] == 0) ready.add(dependent);
    }
  }

  if (ordered.length != tables.length) {
    final Set<String> settled = ordered.map((DeclaredSqlTable table) => table.name).toSet();
    final String stuck = tables
        .map((DeclaredSqlTable table) => table.name)
        .where((String name) => !settled.contains(name))
        .join(', ');
    throwToolExit('these tables reference each other in a cycle and cannot be ordered: $stuck.');
  }

  return ordered;
}
