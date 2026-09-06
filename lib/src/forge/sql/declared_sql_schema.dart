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
///
/// Each of [init], [migrations] and [provisioning] is what one of `Schema`'s own batches declared
/// into it: `Table`, `Sequence`, `Enum`, `Type`, `Extension`, `Grant` and `Drop` no longer carry a
/// moment of their own, `schema.md`'s own `## Schema` section gives the reason, so which of the
/// three a declaration landed under is entirely a fact about which batch listed it.
class DeclaredSqlSchema {
  /// Holds what the bridge read off the package's `schema/` files.
  const DeclaredSqlSchema({required this.init, required this.migrations, required this.provisioning});

  /// Everything declared for the `init` moment.
  final DeclaredSqlMoment init;

  /// Everything declared for the `migrations` moment.
  final DeclaredSqlMoment migrations;

  /// Everything declared for the `provisioning` moment.
  final DeclaredSqlMoment provisioning;

  /// Reads a whole schema from the JSON object the bridge prints.
  factory DeclaredSqlSchema.fromJson(Map<String, dynamic> json) => DeclaredSqlSchema(
    init: DeclaredSqlMoment.fromJson(json['init'] as Map<String, dynamic>),
    migrations: DeclaredSqlMoment.fromJson(json['migrations'] as Map<String, dynamic>),
    provisioning: DeclaredSqlMoment.fromJson(json['provisioning'] as Map<String, dynamic>),
  );
}

/// Everything one of a package's three `db` moments declared: its tables, and what is tied to one.
class DeclaredSqlMoment {
  /// Holds what the bridge read off every declaration `Schema`'s own batch for this moment carried.
  const DeclaredSqlMoment({
    required this.tables,
    required this.indexes,
    required this.policies,
    required this.grants,
    required this.sequences,
    required this.enums,
    required this.compositeTypes,
    required this.extensions,
    required this.drops,
  });

  /// The tables declared for this moment, in the order they were declared.
  final List<DeclaredSqlTable> tables;

  /// The indexes declared for this moment, through some table's own `options.indexes`.
  final List<DeclaredSqlIndex> indexes;

  /// The row-level security policies declared for this moment, through some table's own `options.policies`.
  final List<DeclaredSqlPolicy> policies;

  /// The privilege grants declared for this moment, through some table's own `options.grants`, or the
  /// standalone `Grant` when batched here.
  final List<DeclaredSqlGrant> grants;

  /// The standalone sequences declared for this moment.
  final List<DeclaredSqlSequence> sequences;

  /// The enums declared for this moment.
  final List<DeclaredSqlEnum> enums;

  /// The composite types declared for this moment.
  final List<DeclaredSqlCompositeType> compositeTypes;

  /// The extensions declared for this moment.
  final List<DeclaredSqlExtension> extensions;

  /// The retirements declared for this moment.
  final List<DeclaredSqlDrop> drops;

  /// Whether this moment carries nothing at all, the case in which nothing is rendered or written for it.
  bool get isEmpty =>
      tables.isEmpty &&
      indexes.isEmpty &&
      policies.isEmpty &&
      grants.isEmpty &&
      sequences.isEmpty &&
      enums.isEmpty &&
      compositeTypes.isEmpty &&
      extensions.isEmpty &&
      drops.isEmpty;

  /// Reads one moment's declarations from the JSON object the bridge prints.
  factory DeclaredSqlMoment.fromJson(Map<String, dynamic> json) => DeclaredSqlMoment(
    tables: (json['tables'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlTable.fromJson(e as Map<String, dynamic>))
        .toList(),
    indexes: (json['indexes'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlIndex.fromJson(e as Map<String, dynamic>))
        .toList(),
    policies: (json['policies'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlPolicy.fromJson(e as Map<String, dynamic>))
        .toList(),
    grants: (json['grants'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlGrant.fromJson(e as Map<String, dynamic>))
        .toList(),
    sequences: (json['sequences'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlSequence.fromJson(e as Map<String, dynamic>))
        .toList(),
    enums: (json['enums'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlEnum.fromJson(e as Map<String, dynamic>))
        .toList(),
    compositeTypes: (json['compositeTypes'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlCompositeType.fromJson(e as Map<String, dynamic>))
        .toList(),
    extensions: (json['extensions'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlExtension.fromJson(e as Map<String, dynamic>))
        .toList(),
    drops: (json['drops'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlDrop.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One sequence, exactly as `Sequence` declared it.
class DeclaredSqlSequence {
  /// Holds a sequence's own settings, exactly as the bridge printed them.
  const DeclaredSqlSequence({
    required this.name,
    this.as,
    this.incrementBy,
    this.minValue,
    this.maxValue,
    this.startWith,
    this.cache,
    required this.cycle,
    this.ownedBy,
  });

  /// The name this sequence is created under.
  final String name;

  /// The Postgres type this sequence's values are represented as. Null for Postgres's own default, `bigint`.
  final String? as;

  /// The step this sequence advances by on each value. Null for Postgres's own default, `1`.
  final int? incrementBy;

  /// The lowest value this sequence produces: an [int], the string `"none"` for no floor, or null
  /// for Postgres's own default for [as].
  final Object? minValue;

  /// The highest value this sequence produces: an [int], the string `"none"` for no ceiling, or
  /// null for Postgres's own default for [as].
  final Object? maxValue;

  /// The value this sequence starts from. Null for its own [minValue].
  final int? startWith;

  /// How many values this sequence precomputes and holds in memory. Null for Postgres's own default, `1`.
  final int? cache;

  /// Whether this sequence wraps back to its bound once exhausted, rather than refusing a further value.
  final bool cycle;

  /// The column this sequence is tied to. Null when it stands on its own.
  final SqlSequenceOwner? ownedBy;

  /// Reads one sequence from the JSON object the bridge prints.
  factory DeclaredSqlSequence.fromJson(Map<String, dynamic> json) => DeclaredSqlSequence(
    name: json['name'] as String,
    as: json['as'] as String?,
    incrementBy: json['incrementBy'] as int?,
    minValue: json['minValue'],
    maxValue: json['maxValue'],
    startWith: json['startWith'] as int?,
    cache: json['cache'] as int?,
    cycle: json['cycle'] as bool,
    ownedBy: json['ownedBy'] != null ? SqlSequenceOwner.fromJson(json['ownedBy'] as Map<String, dynamic>) : null,
  );
}

/// The column a sequence is tied to.
class SqlSequenceOwner {
  /// Holds the [table] and [column] a sequence is tied to.
  const SqlSequenceOwner({required this.table, required this.column});

  /// The table [column] belongs to.
  final String table;

  /// The column this sequence is tied to.
  final String column;

  /// Reads a sequence's owning column from the JSON object the bridge prints.
  factory SqlSequenceOwner.fromJson(Map<String, dynamic> json) =>
      SqlSequenceOwner(table: json['table'] as String, column: json['column'] as String);
}

/// One extension, exactly as `Extension` declared it.
class DeclaredSqlExtension {
  /// Holds an extension's own settings, exactly as the bridge printed them.
  const DeclaredSqlExtension({required this.name, this.schema, this.version, required this.cascade});

  /// The name this extension is installed under.
  final String name;

  /// The schema this extension installs into. Null for the extension's own control file default.
  final String? schema;

  /// The version of the extension to install. Null for its default version.
  final String? version;

  /// Whether to also install any extension this one depends on that is not installed yet.
  final bool cascade;

  /// Reads one extension from the JSON object the bridge prints.
  factory DeclaredSqlExtension.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> options = json['options'] as Map<String, dynamic>;

    return DeclaredSqlExtension(
      name: json['name'] as String,
      schema: options['schema'] as String?,
      version: options['version'] as String?,
      cascade: options['cascade'] as bool? ?? false,
    );
  }
}

/// A retirement, exactly as `Drop` declared it, one subclass per kind of object.
sealed class DeclaredSqlDrop {
  const DeclaredSqlDrop();

  /// The name of the object this retires.
  String get name;

  /// Whether this drops whatever depends on the object too, rather than refusing while a dependent exists.
  bool get cascade;

  /// Reads one retirement from the JSON object the bridge prints.
  factory DeclaredSqlDrop.fromJson(Map<String, dynamic> json) {
    final String name = json['name'] as String;
    final bool cascade = json['cascade'] as bool;

    return switch (json['kind'] as String) {
      'table' => DeclaredSqlDropTable(name: name, cascade: cascade),
      'index' => DeclaredSqlDropIndex(name: name, cascade: cascade),
      'type' => DeclaredSqlDropType(name: name, cascade: cascade),
      'extension' => DeclaredSqlDropExtension(name: name, cascade: cascade),
      'policy' => DeclaredSqlDropPolicy(name: name, table: json['table'] as String, cascade: cascade),
      final String other => throw StateError('Unknown drop kind "$other".'),
    };
  }
}

/// Retires a table.
class DeclaredSqlDropTable extends DeclaredSqlDrop {
  /// Holds the [name] and [cascade] a table's retirement was declared with.
  const DeclaredSqlDropTable({required this.name, required this.cascade});

  @override
  final String name;

  @override
  final bool cascade;
}

/// Retires an index.
class DeclaredSqlDropIndex extends DeclaredSqlDrop {
  /// Holds the [name] and [cascade] an index's retirement was declared with.
  const DeclaredSqlDropIndex({required this.name, required this.cascade});

  @override
  final String name;

  @override
  final bool cascade;
}

/// Retires an enum or a composite type.
class DeclaredSqlDropType extends DeclaredSqlDrop {
  /// Holds the [name] and [cascade] a type's retirement was declared with.
  const DeclaredSqlDropType({required this.name, required this.cascade});

  @override
  final String name;

  @override
  final bool cascade;
}

/// Retires an extension.
class DeclaredSqlDropExtension extends DeclaredSqlDrop {
  /// Holds the [name] and [cascade] an extension's retirement was declared with.
  const DeclaredSqlDropExtension({required this.name, required this.cascade});

  @override
  final String name;

  @override
  final bool cascade;
}

/// Retires a policy carried by a table.
class DeclaredSqlDropPolicy extends DeclaredSqlDrop {
  /// Holds the [name], [table] and [cascade] a policy's retirement was declared with.
  const DeclaredSqlDropPolicy({required this.name, required this.table, required this.cascade});

  @override
  final String name;

  /// The table this policy belongs to.
  final String table;

  @override
  final bool cascade;
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

/// One composite type, exactly as `Type` declared it.
class DeclaredSqlCompositeType {
  /// Holds the [name] and [fields] the bridge read off one `Type` call.
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

/// One table, exactly as `Table` declared it.
class DeclaredSqlTable {
  /// Holds the [name] and [columns] the bridge read off one `Table` call.
  const DeclaredSqlTable({
    required this.name,
    required this.columns,
    required this.rowLevelSecurity,
    required this.revokes,
  });

  /// The name this table is created under.
  final String name;

  /// This table's columns, by name, in the order it will list them.
  final Map<String, DeclaredSqlColumn> columns;

  /// Whether this table refuses every row to every role except through a policy that lets it through.
  final bool rowLevelSecurity;

  /// The privileges taken back from a role on this table, the mirror of its own grants.
  final List<DeclaredSqlRevoke> revokes;

  /// Reads one table from the JSON object the bridge prints.
  factory DeclaredSqlTable.fromJson(Map<String, dynamic> json) => DeclaredSqlTable(
    name: json['name'] as String,
    columns: (json['columns'] as Map<String, dynamic>).map(
      (String column, dynamic definition) =>
          MapEntry<String, DeclaredSqlColumn>(column, DeclaredSqlColumn.fromJson(definition as Map<String, dynamic>)),
    ),
    rowLevelSecurity: json['rowLevelSecurity'] as bool,
    revokes: (json['revokes'] as List<dynamic>)
        .map((dynamic e) => DeclaredSqlRevoke.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One privilege revocation, the mirror of [DeclaredSqlGrant], exactly as some table's own `options.revokes` carried it.
class DeclaredSqlRevoke {
  /// Holds the [privileges] taken back and the roles they are taken back [from].
  const DeclaredSqlRevoke({required this.privileges, required this.from});

  /// The privileges taken back, explicitly. Null when TypeScript's `"all"` was given instead, meaning
  /// every privilege the table carries.
  final List<String>? privileges;

  /// The roles the privileges are taken back from.
  final List<String> from;

  /// Reads one revocation from the JSON object the bridge prints.
  factory DeclaredSqlRevoke.fromJson(Map<String, dynamic> json) => DeclaredSqlRevoke(
    privileges: json['privileges'] is List<dynamic> ? (json['privileges'] as List<dynamic>).cast<String>() : null,
    from: (json['from'] as List<dynamic>).cast<String>(),
  );
}

/// One column of a table, exactly as one entry of a `Table`'s `columns` built it.
class DeclaredSqlColumn {
  /// Holds a column's definition, read off one entry of a `Table`'s `columns`.
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
    primaryKey: json['isPrimary'] as bool,
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
///
/// [kind] covers only the subset of `ColumnType`'s own kinds this renderer knows how to emit —
/// `uuid`, `text`, `varchar`, `bigint`, `integer`, `boolean`, `timestamp`, `jsonb`, `bigserial`,
/// `enum`, `composite`, `array`. A package reaching for one of the many kinds `ColumnType` accepts
/// beyond these throws a tool exit naming it at render time, in `emit_sql.dart`, rather than
/// refusing it here where the shape is still just data.
class SqlColumnType {
  /// Holds a type exactly as the bridge printed it.
  const SqlColumnType({required this.kind, this.length, this.name, this.of});

  /// Which shape this type takes.
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

/// One index, exactly as some table's own `options.indexes` carried it.
class DeclaredSqlIndex {
  /// Holds the [name] and [options] the bridge read off one entry of a `Table`'s `indexes`.
  const DeclaredSqlIndex({required this.name, required this.options});

  /// The name this index is created under.
  final String name;

  /// What it covers, and the constraints it carries.
  final SqlIndexOptions options;

  /// Reads one index from the JSON object the bridge prints.
  factory DeclaredSqlIndex.fromJson(Map<String, dynamic> json) => DeclaredSqlIndex(
    name: json['name'] as String,
    options: SqlIndexOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// What an index covers and the constraints it carries.
class SqlIndexOptions {
  /// Holds an index's options exactly as the bridge printed them.
  const SqlIndexOptions({required this.table, required this.columns, required this.unique, this.using, this.where});

  /// The table this index covers.
  final String table;

  /// The columns this index covers, in the order it will list them. An entry may be a raw
  /// expression, `lower(email)`, rather than a bare column name.
  final List<String> columns;

  /// Whether this index refuses a row whose covered columns match one already stored.
  final bool unique;

  /// The access method this index is built with. Null when Postgres's own default, `btree`, applies.
  final String? using;

  /// The raw predicate this index is restricted to. Null when it covers every row.
  final String? where;

  /// Reads one index's options from the JSON object the bridge prints.
  ///
  /// An entry of `columns` that arrived as an object rather than a bare string — one carrying a
  /// collation, an operator class, or its own sort order — is read by its own `expression` alone:
  /// this renderer does not yet emit the rest of what that object can carry.
  factory SqlIndexOptions.fromJson(Map<String, dynamic> json) => SqlIndexOptions(
    table: json['table'] as String,
    columns: (json['columns'] as List<dynamic>)
        .map((dynamic column) => column is String ? column : (column as Map<String, dynamic>)['expression'] as String)
        .toList(),
    unique: json['unique'] as bool? ?? false,
    using: json['using'] as String?,
    where: json['where'] as String?,
  );
}

/// One row-level security policy, exactly as some table's own `options.policies` carried it.
class DeclaredSqlPolicy {
  /// Holds the [name] and [options] the bridge read off one entry of a `Table`'s `policies`.
  const DeclaredSqlPolicy({required this.name, required this.options});

  /// The name this policy is created under.
  final String name;

  /// The table it guards, who it applies to, and the rows it lets through.
  final SqlPolicyOptions options;

  /// Reads one policy from the JSON object the bridge prints.
  factory DeclaredSqlPolicy.fromJson(Map<String, dynamic> json) => DeclaredSqlPolicy(
    name: json['name'] as String,
    options: SqlPolicyOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// What a policy guards, who it applies to, and the rows it lets through.
class SqlPolicyOptions {
  /// Holds a policy's options exactly as the bridge printed them.
  const SqlPolicyOptions({required this.table, this.command, this.kind, this.to, this.using, this.withCheck});

  /// The table this policy guards.
  final String table;

  /// The statement this policy applies to, TypeScript's `for` — `for` and `as` are Dart keywords,
  /// so neither field is named after the JSON key it reads. Null reads as `all`, Postgres's own default.
  final String? command;

  /// Whether this policy narrows (`permissive`) or additionally restricts (`restrictive`), TypeScript's
  /// `as`. Null reads as `permissive`, Postgres's own default.
  final String? kind;

  /// The roles this policy applies to. Null or empty reads as every role, Postgres's own default.
  final List<String>? to;

  /// The raw predicate a row must satisfy to be visible or touchable. Null when it carries none.
  final String? using;

  /// The raw predicate a written row must satisfy. Null when it carries none.
  final String? withCheck;

  /// Reads one policy's options from the JSON object the bridge prints.
  factory SqlPolicyOptions.fromJson(Map<String, dynamic> json) => SqlPolicyOptions(
    table: json['table'] as String,
    command: json['for'] as String?,
    kind: json['as'] as String?,
    to: (json['to'] as List<dynamic>?)?.cast<String>(),
    using: json['using'] as String?,
    withCheck: json['withCheck'] as String?,
  );
}

/// One privilege grant, exactly as some table's own `options.grants` carried it, or the standalone `Grant`.
class DeclaredSqlGrant {
  /// Holds the [options] the bridge read off one grant — a grant carries no name of its own.
  const DeclaredSqlGrant({required this.options});

  /// What it grants, on what, and to whom.
  final SqlGrantOptions options;

  /// Reads one grant from the JSON object the bridge prints.
  factory DeclaredSqlGrant.fromJson(Map<String, dynamic> json) =>
      DeclaredSqlGrant(options: SqlGrantOptions.fromJson(json['options'] as Map<String, dynamic>));
}

/// What a grant grants, on what, and to whom.
class SqlGrantOptions {
  /// Holds a grant's options exactly as the bridge printed them.
  const SqlGrantOptions({required this.privileges, required this.on, required this.to, this.withGrantOption});

  /// The privileges granted, explicitly. Null when TypeScript's `"all"` was given instead, meaning
  /// every privilege [on]'s kind of object carries.
  final List<String>? privileges;

  /// The object the privileges apply to.
  final SqlGrantObject on;

  /// The roles granted the privileges.
  final List<String> to;

  /// Whether a grantee may re-grant the same privileges to somebody else in turn. Null reads as false.
  final bool? withGrantOption;

  /// Reads one grant's options from the JSON object the bridge prints.
  factory SqlGrantOptions.fromJson(Map<String, dynamic> json) => SqlGrantOptions(
    privileges: json['privileges'] is List<dynamic> ? (json['privileges'] as List<dynamic>).cast<String>() : null,
    on: SqlGrantObject.fromJson(json['on'] as Map<String, dynamic>),
    to: (json['to'] as List<dynamic>).cast<String>(),
    withGrantOption: json['withGrantOption'] as bool?,
  );
}

/// The object a grant applies to.
class SqlGrantObject {
  /// Holds the [kind] and [name] of the object a grant names.
  const SqlGrantObject({required this.kind, required this.name});

  /// What kind of object [name] is: `table`, `sequence`, `schema`, `function`, `database`, `domain`, `type`.
  final String kind;

  /// The object's own name.
  final String name;

  /// Reads one grant object from the JSON object the bridge prints.
  factory SqlGrantObject.fromJson(Map<String, dynamic> json) =>
      SqlGrantObject(kind: json['kind'] as String, name: json['name'] as String);
}
