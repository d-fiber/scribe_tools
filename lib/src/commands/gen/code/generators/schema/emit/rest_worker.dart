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

  final Set<String> used = <String>{for (final String table in extended) ...enumsUsedBy(schema.tables[table]!.cols)};

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

String _extendedRow(String table) => '${table.toPascalCase()}KernelColumns & ${table.toPascalCase()}ProjectColumns';

List<String> _method(String table, String row) => <String>[
  '  $table(): RestQuery<$row> {',
  '    return new RestQuery<$row>("$table");',
  '  }',
];
