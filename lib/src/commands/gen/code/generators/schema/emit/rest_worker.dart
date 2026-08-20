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
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/generated_header.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/schema_scan.dart';
import 'package:scribe_tools/src/commands/gen/code/sql/table_schema.dart';

/// The lines of `worker.ts`: the same tables, reached from another process.
///
/// A worker cannot import `@scribe/core/` or `@scribe/host/`, because it runs
/// somewhere else, possibly without the host on disk at all. The framework
/// columns of an extended table are therefore redeclared here from the same
/// SQL rather than imported, which is the one duplication this file accepts.
List<String> renderRestWorker(SqlSchema schema, Set<String> projectEnums) {
  final List<String> owned = schema.sortedProjectTables;
  final List<String> extended = schema.extendedTables;

  final Set<String> used = <String>{
    for (final String table in extended) ...enumsUsedBy(schema.tables[table]!.cols),
  };

  return <String>[
    ...generatedHeader(),
    'import { RestQuery } from "@scribe/sdk";',
    ...enumImports(used, projectEnums),
    'import type {',
    for (final String table in owned) '  ${table.toPascalCase()}Row,',
    for (final String table in extended) '  ${table.toPascalCase()}ProjectColumns,',
    '} from "./_rows.generated.ts";',
    '',
    for (final String table in extended) ...<String>[
      'export interface ${table.toPascalCase()}KernelColumns {',
      for (final Col column in schema.tables[table]!.cols) '  ${column.name}: ${column.ts};',
      '}',
      '',
    ],
    'export class WorkerTables {',
    for (final String table in owned) ..._method(table, '${table.toPascalCase()}Row'),
    for (final String table in extended) ..._method(table, _extendedRow(table)),
    '}',
    '',
    'export const rest = new WorkerTables();',
    '',
  ];
}

String _extendedRow(String table) =>
    '${table.toPascalCase()}KernelColumns & ${table.toPascalCase()}ProjectColumns';

List<String> _method(String table, String row) => <String>[
  '  $table(): RestQuery<$row> {',
  '    return new RestQuery<$row>("$table");',
  '  }',
];
