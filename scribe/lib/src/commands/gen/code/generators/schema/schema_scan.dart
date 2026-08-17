// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/table_owners.dart';
import 'package:scribe/src/commands/gen/code/sql/table_schema.dart';
import 'package:scribe/src/commands/gen/sql_scanner.dart';
import 'package:scribe/src/globals.dart' as globals;

/// Everything the framework SQL and the project SQL declare, read together.
class SqlSchema {
  const SqlSchema({
    required this.tables,
    required this.projectTables,
    required this.owners,
    required this.projectExtensions,
  });

  /// Every table found, by name, columns included.
  final Map<String, TableSchema> tables;

  /// The tables whose `CREATE TABLE` lives in the project's own SQL.
  ///
  /// These are the ones the project owns outright, as opposed to a framework
  /// table it merely adds a column to.
  final Set<String> projectTables;

  /// The column each owned table is owned through. See [ownerColumnOf].
  final Map<String, String> owners;

  /// The columns the project's SQL adds to a table the framework declares.
  ///
  /// They are kept apart from [tables] rather than merged into them: a
  /// framework row type that carried a project column would reference a
  /// project enum, and the SDK would stop compiling on its own.
  final Map<String, List<Col>> projectExtensions;

  /// The names of every table, sorted.
  List<String> get sortedNames => tables.keys.toList()..sort();

  /// The tables the framework declares, sorted.
  List<String> get frameworkTables =>
      sortedNames.where((String table) => !projectTables.contains(table)).toList();

  /// The tables the project declares, sorted.
  List<String> get sortedProjectTables => projectTables.toList()..sort();

  /// The framework tables the project extends, sorted.
  List<String> get extendedTables => projectExtensions.keys.toList()..sort();

  /// Whether the project declares no table and extends none.
  bool get hasNothingOfItsOwn => projectTables.isEmpty && projectExtensions.isEmpty;
}

/// An `ALTER TABLE` seen before it is known which side declared its table.
///
/// Whether the added columns belong in the table itself or in
/// [SqlSchema.projectExtensions] depends on where the `CREATE TABLE` was found,
/// and a project file may be read before the framework file it extends.
class _PendingAlter {
  const _PendingAlter(this.table, this.body, {required this.fromProject});

  final String table;
  final String body;
  final bool fromProject;
}

/// Reads every `.sql` of the framework and of the project into one [SqlSchema].
///
/// The framework roots are read first, so a project file that repeats a table
/// name does not take it over. `ALTER TABLE` statements are held back until the
/// whole scan is done. See [_PendingAlter].
Future<SqlSchema> scanSqlSchema() async {
  final Map<String, TableSchema> tables = <String, TableSchema>{};
  final Set<String> projectTables = <String>{};
  final Map<String, String> owners = <String, String>{};
  final List<_PendingAlter> alters = <_PendingAlter>[];

  Future<void> scan(File file, {required bool fromProject}) async {
    final String sql = await file.readAsString();

    for (final RegExpMatch match in createTableRe.allMatches(sql)) {
      final String table = match.group(1)!;
      if (tables.containsKey(table)) continue;

      final String body = match.group(2)!;
      tables[table] = TableSchema(table, parseColumns(body));
      if (ownerColumnOf(table, body) case final String owner) owners[table] = owner;
      if (fromProject) projectTables.add(table);
    }

    for (final RegExpMatch match in alterTableAddColumnRe.allMatches(sql)) {
      alters.add(_PendingAlter(match.group(1)!, match.group(2)!, fromProject: fromProject));
    }
  }

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, (File file) => scan(file, fromProject: false));
  }
  await walkSqlFiles(globals.project.init, (File file) => scan(file, fromProject: true));

  return SqlSchema(
    tables: tables,
    projectTables: projectTables,
    owners: owners,
    projectExtensions: _resolveAlters(alters, tables, projectTables),
  );
}

/// Files each held-back `ALTER TABLE` where its columns belong.
///
/// A project alter on a framework table becomes an extension; anything else is
/// merged straight into the table, since both sides then belong to the same
/// generated surface.
Map<String, List<Col>> _resolveAlters(
  List<_PendingAlter> alters,
  Map<String, TableSchema> tables,
  Set<String> projectTables,
) {
  final Map<String, List<Col>> extensions = <String, List<Col>>{};

  for (final _PendingAlter alter in alters) {
    final TableSchema? schema = tables[alter.table];
    if (schema == null) continue;

    final List<Col> added = parseAlterAddColumns(alter.body);
    if (alter.fromProject && !projectTables.contains(alter.table)) {
      (extensions[alter.table] ??= <Col>[]).addAll(added);
      continue;
    }

    schema.cols.addAll(added);
  }

  return extensions;
}
