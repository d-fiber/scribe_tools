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

/// The lines of `_rows.generated.ts`: one interface per row the project owns.
///
/// A table the project extends gets a second interface holding only the columns
/// the project added, so the framework's own row type stays untouched and the
/// two are intersected where they are used.
List<String> renderRestRows(SqlSchema schema, Set<String> projectEnums) {
  final List<String> owned = schema.sortedProjectTables;
  final List<String> extended = schema.extendedTables;

  final Set<String> used = <String>{
    for (final String table in owned) ...enumsUsedBy(schema.tables[table]!.cols),
    for (final List<Col> columns in schema.projectExtensions.values) ...enumsUsedBy(columns),
  };

  return <String>[
    ...generatedHeader(),
    ...enumImports(used, projectEnums),
    for (final String table in owned) ..._interface('${table.toPascalCase()}Row', schema.tables[table]!.cols),
    for (final String table in extended)
      ..._interface('${table.toPascalCase()}ProjectColumns', schema.projectExtensions[table]!),
  ];
}

List<String> _interface(String name, List<Col> columns) => <String>[
  'export interface $name {',
  for (final Col column in columns) '  ${column.name}: ${column.ts};',
  '}',
  '',
];
