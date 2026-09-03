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

/// The SQL that provisions [schema] into [packageName]'s own schema.
///
/// Every table, type and enum is qualified `<packageName>.<name>`, and nothing here creates that
/// schema: `run-provision.sh` does, once, before playing a package's `deploy/db/init/` — the same
/// division that keeps a package's SQL ignorant of the roles and the extensions the stack sets up
/// around it.
///
/// A column's or a field's name is written in snake_case whatever case the object literal that
/// declared it used, since a TypeScript author reaches for camelCase by reflex and every hand
/// written column in this framework is snake_case. A table's, an enum's or a composite type's own
/// name is never touched: it is a string an author already chose on purpose, not an object key.
///
/// Enums come first, then composite types, then tables ordered so a table referenced by a foreign
/// key is created before the table that carries it, then functions, then triggers, then scheduled
/// jobs. Throws a [ToolExit] naming the tables when two or more of them reference each other in a
/// cycle, since no order would satisfy every foreign key.
///
/// A function is created before every trigger, since `create trigger` refuses to name one that
/// does not exist yet. Nothing here checks that a trigger's table or function was actually
/// declared: Postgres itself refuses a trigger naming either that does not exist.
String emitSql({required String packageName, required DeclaredSqlSchema schema}) {
  final StringBuffer sql = StringBuffer();

  for (final DeclaredSqlEnum declaredEnum in schema.enums) {
    sql.writeln(_emitEnum(packageName, declaredEnum));
  }
  for (final DeclaredSqlCompositeType compositeType in schema.compositeTypes) {
    sql.writeln(_emitCompositeType(packageName, compositeType));
  }
  for (final DeclaredSqlTable table in _orderedTables(schema.tables)) {
    sql.writeln(_emitTable(packageName, table));
  }
  for (final DeclaredSqlFunction function in schema.functions) {
    sql.writeln(_emitFunction(packageName, function));
  }
  for (final DeclaredSqlTrigger trigger in schema.triggers) {
    sql.writeln(_emitTrigger(packageName, trigger));
  }
  for (final DeclaredSqlCronJob cronJob in schema.cronJobs) {
    sql.writeln(_emitCronJob(cronJob));
  }

  return sql.toString();
}

String _emitEnum(String packageName, DeclaredSqlEnum declaredEnum) {
  final String values = declaredEnum.values.map((String value) => "  '$value'").join(',\n');
  return 'create type $packageName.${declaredEnum.name} as enum (\n$values\n);\n';
}

String _emitCompositeType(String packageName, DeclaredSqlCompositeType compositeType) {
  final String fields = compositeType.fields.entries
      .map(
        (MapEntry<String, SqlColumnType> field) => '  ${field.key.toSnakeCase()} ${_sqlType(packageName, field.value)}',
      )
      .join(',\n');
  return 'create type $packageName.${compositeType.name} as (\n$fields\n);\n';
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
  return 'create table if not exists $packageName.${table.name} (\n$columns\n);\n';
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

String _emitFunction(String packageName, DeclaredSqlFunction function) {
  final SqlFunctionOptions options = function.options;
  final StringBuffer sql = StringBuffer('create or replace function $packageName.${function.name}()\n')
    ..write('returns ${options.returns}\n')
    ..write('language ${options.language}\n');
  if (options.security == 'definer') sql.write('security definer\n');
  if (options.searchPath != null) sql.write('set search_path = ${options.searchPath}\n');
  sql.write('as \$\$\n${options.body}\n\$\$;\n');
  return sql.toString();
}

String _emitTrigger(String packageName, DeclaredSqlTrigger trigger) {
  final SqlTriggerOptions options = trigger.options;
  final String events = options.events.join(' or ');
  final StringBuffer sql = StringBuffer('drop trigger if exists ${trigger.name} on $packageName.${options.table};\n')
    ..write('create trigger ${trigger.name}\n')
    ..write('  ${options.timing} $events on $packageName.${options.table}\n')
    ..write('  for each ${options.forEach}\n')
    ..write('  execute function $packageName.${options.function}();\n');
  return sql.toString();
}

String _emitCronJob(DeclaredSqlCronJob cronJob) {
  final SqlCronJobOptions options = cronJob.options;
  final String command = options.command.replaceAll("'", "''");
  return "select cron.schedule('${cronJob.name}', '${options.schedule}', '$command');\n";
}

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
  'timestamptz' => 'timestamptz',
  'jsonb' => 'jsonb',
  'bigserial' => 'bigserial',
  'enum' => '$packageName.${type.name}',
  'composite' => '$packageName.${type.name}',
  'array' => '${_sqlType(packageName, type.of!)}[]',
  _ => throwToolExit('unknown column type "${type.kind}", the schema bridge and this renderer have drifted apart.'),
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
