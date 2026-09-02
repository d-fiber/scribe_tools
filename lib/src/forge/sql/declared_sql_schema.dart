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

/// Everything one run of the schema bridge found, which is one package's whole schema.
class DeclaredSqlSchema {
  /// Holds what the bridge read off the package's `schema/` files.
  const DeclaredSqlSchema({
    required this.enums,
    required this.compositeTypes,
    required this.tables,
    required this.functions,
    required this.triggers,
    required this.cronJobs,
  });

  /// The enums the package declared, in the order it declared them.
  final List<DeclaredSqlEnum> enums;

  /// The composite types the package declared, in the order it declared them.
  final List<DeclaredSqlCompositeType> compositeTypes;

  /// The tables the package declared, in the order it declared them.
  final List<DeclaredSqlTable> tables;

  /// The functions the package declared, in the order it declared them.
  final List<DeclaredSqlFunction> functions;

  /// The triggers the package declared, in the order it declared them.
  final List<DeclaredSqlTrigger> triggers;

  /// The scheduled jobs the package declared, in the order it declared them.
  final List<DeclaredSqlCronJob> cronJobs;

  /// Reads a whole schema from the JSON the bridge prints.
  factory DeclaredSqlSchema.fromJson(Map<String, dynamic> json) => DeclaredSqlSchema(
    enums: (json['enums'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlEnum.fromJson(e as Map<String, dynamic>))
        .toList(),
    compositeTypes: (json['compositeTypes'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlCompositeType.fromJson(e as Map<String, dynamic>))
        .toList(),
    tables: (json['tables'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlTable.fromJson(e as Map<String, dynamic>))
        .toList(),
    functions: (json['functions'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlFunction.fromJson(e as Map<String, dynamic>))
        .toList(),
    triggers: (json['triggers'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlTrigger.fromJson(e as Map<String, dynamic>))
        .toList(),
    cronJobs: (json['cronJobs'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlCronJob.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One enum, exactly as `Enum` declared it.
class DeclaredSqlEnum {
  /// Holds the [name] and [values] the bridge read off one `Enum` call.
  const DeclaredSqlEnum({required this.name, required this.values});

  /// The name this enum is created under.
  final String name;

  /// The values this enum accepts, in the order it will list them.
  final List<String> values;

  /// Reads one enum from the JSON object the bridge prints.
  factory DeclaredSqlEnum.fromJson(Map<String, dynamic> json) =>
      DeclaredSqlEnum(name: json['name'] as String, values: (json['values'] as List<dynamic>).cast<String>());
}

/// One composite type, exactly as `@CompositeType` declared it.
class DeclaredSqlCompositeType {
  /// Holds the [name] and [fields] the bridge read off one `@CompositeType` class.
  const DeclaredSqlCompositeType({required this.name, required this.fields});

  /// The name this type is created under.
  final String name;

  /// This type's fields, by name, in the order it will list them.
  final Map<String, SqlColumnType> fields;

  /// Reads one composite type from the JSON object the bridge prints.
  factory DeclaredSqlCompositeType.fromJson(Map<String, dynamic> json) => DeclaredSqlCompositeType(
    name: json['name'] as String,
    fields: (json['fields'] as Map<String, dynamic>).map(
      (String field, dynamic type) =>
          MapEntry<String, SqlColumnType>(field, SqlColumnType.fromJson(type as Map<String, dynamic>)),
    ),
  );
}

/// One table, exactly as `@Table` declared it.
class DeclaredSqlTable {
  /// Holds the [name] and [columns] the bridge read off one `@Table` class.
  const DeclaredSqlTable({required this.name, required this.columns});

  /// The name this table is created under.
  final String name;

  /// This table's columns, by name, in the order it will list them.
  final Map<String, DeclaredSqlColumn> columns;

  /// Reads one table from the JSON object the bridge prints.
  factory DeclaredSqlTable.fromJson(Map<String, dynamic> json) => DeclaredSqlTable(
    name: json['name'] as String,
    columns: (json['columns'] as Map<String, dynamic>).map(
      (String column, dynamic definition) =>
          MapEntry<String, DeclaredSqlColumn>(column, DeclaredSqlColumn.fromJson(definition as Map<String, dynamic>)),
    ),
  );
}

/// One column of a table, exactly as `Column` built it.
class DeclaredSqlColumn {
  /// Holds a column's definition, read off one `@Column` of a `@Table` class.
  const DeclaredSqlColumn({
    required this.type,
    required this.notNull,
    required this.primaryKey,
    required this.unique,
    this.defaultSql,
    this.references,
  });

  /// The Postgres type this column holds.
  final SqlColumnType type;

  /// Whether this column refuses a null value.
  final bool notNull;

  /// Whether this column is the table's primary key.
  final bool primaryKey;

  /// Whether this column refuses a value another row already holds.
  final bool unique;

  /// A raw Postgres expression this column takes when a row does not give it one. Null when it takes none.
  final String? defaultSql;

  /// The foreign key this column carries. Null when it carries none.
  final SqlColumnReference? references;

  /// Reads one column from the JSON object the bridge prints.
  factory DeclaredSqlColumn.fromJson(Map<String, dynamic> json) => DeclaredSqlColumn(
    type: SqlColumnType.fromJson(json['type'] as Map<String, dynamic>),
    notNull: json['notNull'] as bool,
    primaryKey: json['primaryKey'] as bool,
    unique: json['unique'] as bool,
    defaultSql: json['defaultSql'] as String?,
    references: json['references'] != null
        ? SqlColumnReference.fromJson(json['references'] as Map<String, dynamic>)
        : null,
  );
}

/// A foreign key, from a column to another table's column.
class SqlColumnReference {
  /// Holds the [table] and [column] a foreign key points at, and what it does on delete.
  const SqlColumnReference({required this.table, required this.column, this.onDelete});

  /// The table this column points at.
  final String table;

  /// The column of [table] this column points at.
  final String column;

  /// What happens to the row when the referenced row is deleted. Null when nothing special does.
  final String? onDelete;

  /// Reads a foreign key from the JSON object the bridge prints.
  factory SqlColumnReference.fromJson(Map<String, dynamic> json) => SqlColumnReference(
    table: json['table'] as String,
    column: json['column'] as String,
    onDelete: json['onDelete'] as String?,
  );
}

/// The Postgres type a column or a composite type field holds.
///
/// [length] is set only when [kind] is `varchar`. [name] is set only when [kind] is `enum` or
/// `composite`, naming another declaration of the same package. [of] is set only when [kind] is
/// `array`, naming what it is an array of.
class SqlColumnType {
  /// Holds a type exactly as the bridge printed it.
  const SqlColumnType({required this.kind, this.length, this.name, this.of});

  /// Which shape this type takes: `uuid`, `text`, `varchar`, `bigint`, `integer`, `boolean`,
  /// `timestamptz`, `jsonb`, `bigserial`, `enum`, `composite`, or `array`.
  final String kind;

  /// The character limit of a `varchar`.
  final int? length;

  /// The name an `enum` or a `composite` was declared under.
  final String? name;

  /// What an `array` holds.
  final SqlColumnType? of;

  /// Reads one type from the JSON object the bridge prints.
  factory SqlColumnType.fromJson(Map<String, dynamic> json) => SqlColumnType(
    kind: json['kind'] as String,
    length: json['length'] as int?,
    name: json['name'] as String?,
    of: json['of'] != null ? SqlColumnType.fromJson(json['of'] as Map<String, dynamic>) : null,
  );
}

/// One function, exactly as `SqlFunction` declared it.
class DeclaredSqlFunction {
  /// Holds the [name] and [options] the bridge read off one `SqlFunction` call.
  const DeclaredSqlFunction({required this.name, required this.options});

  /// The name this function is created under.
  final String name;

  /// What it returns, how it runs, and its body.
  final SqlFunctionOptions options;

  /// Reads one function from the JSON object the bridge prints.
  factory DeclaredSqlFunction.fromJson(Map<String, dynamic> json) => DeclaredSqlFunction(
    name: json['name'] as String,
    options: SqlFunctionOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// A function's signature and body, exactly as `SqlFunction` took them.
class SqlFunctionOptions {
  /// Holds a function's options exactly as the bridge printed them.
  const SqlFunctionOptions({
    required this.language,
    required this.returns,
    required this.security,
    this.searchPath,
    required this.body,
  });

  /// The language the body is written in: `sql` or `plpgsql`.
  final String language;

  /// The Postgres type this function returns, spelled the way `create function` takes it.
  final String returns;

  /// Whether it runs as the caller (`invoker`) or as its owner (`definer`).
  final String security;

  /// The schemas it resolves an unqualified name against, regardless of who calls it. Null when nothing pins it.
  final String? searchPath;

  /// Its body, raw Postgres between `$$`.
  final String body;

  /// Reads one function's options from the JSON object the bridge prints.
  factory SqlFunctionOptions.fromJson(Map<String, dynamic> json) => SqlFunctionOptions(
    language: json['language'] as String? ?? 'plpgsql',
    returns: json['returns'] as String,
    security: json['security'] as String? ?? 'invoker',
    searchPath: json['searchPath'] as String?,
    body: json['body'] as String,
  );
}

/// One trigger, exactly as `SqlTrigger` declared it.
class DeclaredSqlTrigger {
  /// Holds the [name] and [options] the bridge read off one `SqlTrigger` call.
  const DeclaredSqlTrigger({required this.name, required this.options});

  /// The name this trigger is created under.
  final String name;

  /// What it watches, when it fires, and what it executes.
  final SqlTriggerOptions options;

  /// Reads one trigger from the JSON object the bridge prints.
  factory DeclaredSqlTrigger.fromJson(Map<String, dynamic> json) => DeclaredSqlTrigger(
    name: json['name'] as String,
    options: SqlTriggerOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// What a trigger watches and executes, exactly as `SqlTrigger` took it.
class SqlTriggerOptions {
  /// Holds a trigger's options exactly as the bridge printed them.
  const SqlTriggerOptions({
    required this.table,
    required this.timing,
    required this.events,
    required this.function,
    required this.forEach,
  });

  /// The table this trigger watches.
  final String table;

  /// When it fires relative to the events it watches: `before`, `after`, or `instead of`.
  final String timing;

  /// The events that fire it: `insert`, `update`, `delete`, `truncate`.
  final List<String> events;

  /// The name of the `SqlFunction` this trigger executes.
  final String function;

  /// Whether it fires once per matched row or once for the whole statement: `row` or `statement`.
  final String forEach;

  /// Reads one trigger's options from the JSON object the bridge prints.
  factory SqlTriggerOptions.fromJson(Map<String, dynamic> json) => SqlTriggerOptions(
    table: json['table'] as String,
    timing: json['timing'] as String,
    events: (json['events'] as List<dynamic>).cast<String>(),
    function: json['function'] as String,
    forEach: json['forEach'] as String? ?? 'row',
  );
}

/// One scheduled job, exactly as `SqlCronJob` declared it.
class DeclaredSqlCronJob {
  /// Holds the [name] and [options] the bridge read off one `SqlCronJob` call.
  const DeclaredSqlCronJob({required this.name, required this.options});

  /// The name `pg_cron` schedules this job under.
  final String name;

  /// When it runs, and what it runs.
  final SqlCronJobOptions options;

  /// Reads one scheduled job from the JSON object the bridge prints.
  factory DeclaredSqlCronJob.fromJson(Map<String, dynamic> json) => DeclaredSqlCronJob(
    name: json['name'] as String,
    options: SqlCronJobOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// When a scheduled job runs and what it runs, exactly as `SqlCronJob` took them.
class SqlCronJobOptions {
  /// Holds a scheduled job's options exactly as the bridge printed them.
  const SqlCronJobOptions({required this.schedule, required this.command});

  /// A `pg_cron` schedule, five fields.
  final String schedule;

  /// The SQL command `pg_cron` runs on [schedule].
  final String command;

  /// Reads one scheduled job's options from the JSON object the bridge prints.
  factory SqlCronJobOptions.fromJson(Map<String, dynamic> json) =>
      SqlCronJobOptions(schedule: json['schedule'] as String, command: json['command'] as String);
}
