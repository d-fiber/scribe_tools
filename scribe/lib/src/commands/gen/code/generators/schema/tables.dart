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

import 'package:scribe/src/commands/gen/code/generators/schema/emit/rest_client.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/emit/rest_owners.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/emit/rest_rows.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/emit/rest_tables.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/emit/rest_worker.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/schema_scan.dart';
import 'package:scribe/src/commands/gen/code/relations/relations_markers.dart';
import 'package:scribe/src/commands/gen/code/sql/sql_type_mapper.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';

/// Rewrites the typed PostgREST client from the SQL of the framework and the project.
///
/// [projectEnums] names the enums the project declares, so an import can be
/// routed to the right side — it comes from the enum generator, which runs
/// first.
///
/// Nothing is written for the framework's own tables. They are read to know
/// what the project inherits and to avoid redeclaring a table of the base, but
/// their generated surface ships with the framework.
Future<void> generateTables(Set<String> projectEnums) async {
  await loadComposites();
  globals.logger.printStatus('${composites.length} composite types loaded');

  final SqlSchema schema = await scanSqlSchema();
  globals.logger.printStatus('${schema.frameworkTables.length} kernel tables read from the SDK');

  if (schema.hasNothingOfItsOwn) return;

  await _writeRest(schema, projectEnums);
  _reportWhatWasWritten(schema);
}

/// Writes the four files of the generated `rest/` directory.
///
/// `tables.ts` is read before it is overwritten: its relations section is the
/// only part of it this generator does not produce.
Future<void> _writeRest(SqlSchema schema, Set<String> projectEnums) async {
  final GeneratedRest rest = globals.project.generated.sdk.rest;
  await rest.create();

  final Set<String> withRelations = tablesWithRelationsIn(
    await readRelationsSection(rest.tables),
    schema.sortedProjectTables,
  );

  await rest.rows.writeAsString(renderRestRows(schema, projectEnums).join('\n'));
  await rest.owners.writeAsString(renderRestOwners(schema).join('\n'));
  await rest.tables.writeAsString(renderRestTables(schema, tablesWithRelations: withRelations).join('\n'));
  await rest.client.writeAsString(renderRestClient().join('\n'));
  await rest.worker.writeAsString(renderRestWorker(schema, projectEnums).join('\n'));
}

void _reportWhatWasWritten(SqlSchema schema) {
  final int owned = schema.sortedProjectTables.length;
  final int extended = schema.extendedTables.length;
  final int withOwner = schema.sortedProjectTables.where(schema.owners.containsKey).length;
  final String where = '${globals.project.generatedDirectoryName}/sdk/js/rest';

  globals.logger.printStatus('${owned + extended} worker table methods → $where/worker.ts');
  globals.logger.printStatus(
    '$owned project Row interfaces + table methods, $withOwner project table owners → $where/',
  );
}
