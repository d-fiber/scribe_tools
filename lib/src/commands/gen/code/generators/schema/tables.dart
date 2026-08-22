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

import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/rest_client.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/rest_owners.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/rest_rows.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/rest_tables.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/rest_worker.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/schema_scan.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/relations_markers.dart';
import 'package:scribe_tools/src/commands/gen/code/sql/sql_type_mapper.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';

/// Rewrites the typed PostgREST client from the SQL of the framework and the project.
///
/// [projectEnums] names the enums the project declares, so an import can be
/// routed to the right side. It comes from the enum generator, which runs
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

  globals.logger.printStatus('${owned + extended} worker table methods, written to $where/worker.ts');
  globals.logger.printStatus(
    '$owned project Row interfaces and table methods, and $withOwner project table owners, written to $where/',
  );
}
