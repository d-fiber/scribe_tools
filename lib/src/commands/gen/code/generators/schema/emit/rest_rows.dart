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
