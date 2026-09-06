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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The subdirectory of a package's or a project's own root holding what `writeContracts` writes.
///
/// Named distinctly from `kDatabaseDirectory` in `package/deploy.dart`, which is `db`, a package's
/// own SQL under `deploy/`: this one sits at the root a package or a project owns, not under
/// `deploy/`, and holds generated TypeScript rather than SQL.
const String kContractsRootDirectory = 'database';

/// The subdirectory of [kContractsRootDirectory] holding one file per package that carries a `schema/`.
const String kContractsDirectory = 'contracts';

/// The TypeScript `enum`s and `interface`s [schema] declares, one file a project or a package can
/// import a row's or a composite type's shape from without reaching into a package's own `schema/`
/// sources.
///
/// Null when [schema] declares no enum, no composite type and no table at all, the ordinary case
/// for a package that hand-writes its own SQL and carries no `schema/` in the first place.
///
/// Every name is a plain `PascalCase` of the declaration's own name, stripped of a leading or
/// trailing `_` — `__accounts__` becomes `Accounts`, `booking_status` becomes `BookingStatus` —
/// with no attempt to singularize a table's name: `Accounts`, not `Account`. A field keeps
/// whatever case its own `columns` object used, camelCase by convention, since nothing here
/// touches it the way `emit_sql.dart` touches it for the SQL it writes.
///
/// An `enum` or `composite` column of a table becomes a reference to the very type this same call
/// renders for it, `BookingStatus` rather than the wider `string` `RowOf`, in `types/column.ts`,
/// settles for — every declaration [schema] carries is in hand here, so nothing is lost naming it
/// by its real generated type instead. A reference to one declared by a *different* package is not
/// imported: the generated name is still written, and the file is left for its own package's
/// import to complete by hand.
///
/// Covers only the same column kinds `emit_sql.dart` already renders to SQL — `uuid`, `text`,
/// `varchar`, `bigint`, `integer`, `boolean`, `timestamp`, `jsonb`, `bigserial`, `enum`,
/// `composite`, `array` — and throws a [ToolExit] naming any other, the same refusal `emit_sql.dart`
/// raises for the same reason.
String? emitContracts(DeclaredSqlSchema schema) {
  final List<DeclaredSqlMoment> moments = <DeclaredSqlMoment>[schema.init, schema.migrations, schema.provisioning];
  final List<DeclaredSqlTable> tables = <DeclaredSqlTable>[for (final DeclaredSqlMoment m in moments) ...m.tables];
  final List<DeclaredSqlEnum> enums = <DeclaredSqlEnum>[for (final DeclaredSqlMoment m in moments) ...m.enums];
  final List<DeclaredSqlCompositeType> compositeTypes = <DeclaredSqlCompositeType>[
    for (final DeclaredSqlMoment m in moments) ...m.compositeTypes,
  ];
  if (enums.isEmpty && compositeTypes.isEmpty && tables.isEmpty) return null;

  final StringBuffer out = StringBuffer();
  for (final DeclaredSqlEnum declaredEnum in enums) {
    out.writeln(_emitEnum(declaredEnum));
  }
  for (final DeclaredSqlCompositeType compositeType in compositeTypes) {
    out.writeln(_emitInterface(_pascalCase(compositeType.name), compositeType.fields));
  }
  for (final DeclaredSqlTable table in tables) {
    out.writeln(
      _emitInterface(
        _pascalCase(table.name),
        table.columns.map(
          (String name, DeclaredSqlColumn column) => MapEntry<String, SqlColumnType>(name, column.type),
        ),
        notNull: table.columns.map(
          (String name, DeclaredSqlColumn column) => MapEntry<String, bool>(name, column.notNull),
        ),
      ),
    );
  }

  return out.toString();
}

/// Writes this package's own file under [rootDirectory]'s
/// `$kContractsRootDirectory/$kContractsDirectory/`, rebuilt whole every time, the same choice
/// `generate_package_sql.dart` makes for the SQL it owns.
///
/// Answers null and writes nothing when [emitContracts] has nothing to say for [schema].
File? writeContracts({required String rootDirectory, required String packageName, required DeclaredSqlSchema schema}) {
  final String? content = emitContracts(schema);
  if (content == null) return null;

  final File output = globals.fs.file(
    p.join(rootDirectory, kContractsRootDirectory, kContractsDirectory, '$packageName.ts'),
  );
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(content);
  return output;
}

String _emitEnum(DeclaredSqlEnum declaredEnum) {
  final String members = declaredEnum.values
      .map((String value) => '  ${_pascalCase(value)} = ${_tsLiteral(value)},')
      .join('\n');
  return 'export enum ${_pascalCase(declaredEnum.name)} {\n$members\n}\n';
}

String _emitInterface(String name, Map<String, SqlColumnType> fields, {Map<String, bool>? notNull}) {
  final String body = fields.entries
      .map(
        (MapEntry<String, SqlColumnType> field) =>
            '  readonly ${field.key}: ${_tsTypeOf(field.value, notNull: notNull?[field.key] ?? true)};',
      )
      .join('\n');
  return 'export interface $name {\n$body\n}\n';
}

String _tsTypeOf(SqlColumnType type, {required bool notNull}) {
  final String scalar = switch (type.kind) {
    'uuid' => 'string',
    'text' => 'string',
    'varchar' => 'string',
    'bigint' => 'number',
    'integer' => 'number',
    'boolean' => 'boolean',
    'timestamp' => 'string',
    'jsonb' => 'unknown',
    'bigserial' => 'number',
    'enum' => _pascalCase(type.name!),
    'composite' => _pascalCase(type.name!),
    'array' => '${_tsTypeOf(type.of!, notNull: true)}[]',
    _ => throwToolExit(
      'column type "${type.kind}" has no TypeScript contract yet: this covers a smaller '
      'vocabulary than `ColumnType` accepts, and this kind is outside it.',
    ),
  };

  return notNull ? scalar : '$scalar | null';
}

String _tsLiteral(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// `raw`, `PascalCase`, without singularizing it: `__accounts__` becomes `Accounts`,
/// `booking_status` becomes `BookingStatus`.
String _pascalCase(String raw) {
  final String trimmed = raw.replaceAll(RegExp(r'^_+|_+$'), '');
  final Iterable<String> parts = trimmed.split(RegExp(r'[^A-Za-z0-9]+')).where((String part) => part.isNotEmpty);
  return parts.map((String part) => part[0].toUpperCase() + part.substring(1)).join();
}
