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

import 'package:change_case/change_case.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/emit/generated_header.dart';
import 'package:scribe/src/commands/gen/code/generators/schema/schema_scan.dart';
import 'package:scribe/src/commands/gen/code/relations/relations_markers.dart';

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
