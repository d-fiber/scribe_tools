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

import 'package:change_case/change_case.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/generated_header.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/schema_scan.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/relations_markers.dart';

/// The lines of `tables.ts`: one query method per table the project can reach.
///
/// [tablesWithRelations] names the tables a `<X>Relations` type exists for. It
/// comes from the previous run, because relations are generated after tables
/// and read what tables wrote, so a table that gains a relation is
/// typed with it one run later. That is accepted rather than ordering the two
/// generators strictly.
///
/// The file keeps the relations markers, and only those: the imports and the
/// methods are rewritten whole on every run, while the section between the
/// markers is patched afterwards.
List<String> renderRestTables(SqlSchema schema, {required Set<String> tablesWithRelations}) {
  final List<String> owned = schema.sortedProjectTables;
  final List<String> extended = schema.extendedTables;

  return <String>[
    ...generatedHeader(),
    'import "./_owners.ts";',
    'import { Tables } from "@scribe/host/packages/foundation/database/rest/gen/tables.ts";',
    'import { TypedQueryBuilder } from "@scribe/foundation/src/database/query/builder.ts";',
    if (extended.isNotEmpty) ...<String>[
      'import type {',
      for (final String table in extended) '  ${table.toPascalCase()}Row,',
      '} from "@scribe/host/packages/foundation/database/rest/gen/rows.ts";',
    ],
    'import type {',
    for (final String table in owned) '  ${table.toPascalCase()}Row,',
    for (final String table in extended) '  ${table.toPascalCase()}ProjectColumns,',
    '} from "./_rows.generated.ts";',
    '',
    relationsMarkerStart,
    relationsMarkerEnd,
    '',
    'export class ProjectTables extends Tables {',
    for (final String table in owned) ..._ownedMethod(table, hasRelations: tablesWithRelations.contains(table)),
    for (final String table in extended) ..._extendedMethod(table),
    '}',
    '',
  ];
}

List<String> _ownedMethod(String table, {required bool hasRelations}) {
  final String row = '${table.toPascalCase()}Row';
  final String relations = '${table.toPascalCase()}Relations';

  final String declared = hasRelations ? '<$row, $row, $relations>' : '<$row>';
  final String built = hasRelations ? '<$row, $row, $relations>' : '<$row, $row>';

  return <String>[
    '  $table(): TypedQueryBuilder$declared {',
    '    return new TypedQueryBuilder$built(this.db, "$table");',
    '  }',
  ];
}

List<String> _extendedMethod(String table) {
  final String row = '${table.toPascalCase()}Row & ${table.toPascalCase()}ProjectColumns';

  return <String>[
    '  override $table(): TypedQueryBuilder<$row> {',
    '    return new TypedQueryBuilder<$row, $row>(this.db, "$table");',
    '  }',
  ];
}
