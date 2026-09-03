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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/code/sql/table_schema.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The lines every file `gen code` writes opens with.
///
/// The binary is named from [kToolName], so a generated file does not carry
/// the name of the project it was generated for.
List<String> generatedHeader() => <String>[
  '// This file is auto-generated do not edit manually.',
  '// Run: $kToolName gen code',
  '',
];

/// The names of the enum types [columns] use.
///
/// `Col.enumName` already carries the bare name whether the column is an array or not:
/// `mapSqlType` appends `[]` to the TypeScript type it renders, never to the enum name, so there
/// is no array suffix here to strip.
Set<String> enumsUsedBy(Iterable<Col> columns) => <String>{
  for (final Col column in columns)
    if (column.enumName case final String name) name,
};

/// The `import type` lines that bring [used] into a generated file.
///
/// An enum is declared by the framework SQL or by the project's, never by both,
/// so each name is routed to one source: [projectEnums] holds the ones that
/// come from the project, and everything else comes from the SDK.
///
/// The framework's enums are imported from the SDK rather than from the host on
/// purpose. These files are read in-process and by a worker alike, and a worker
/// runs in another process where `@scribe/core/` cannot be resolved. The SDK is
/// the only import the two have in common.
List<String> enumImports(Set<String> used, Set<String> projectEnums) {
  if (used.isEmpty) return const <String>[];

  final List<String> fromSdk = used.where((String e) => !projectEnums.contains(e)).toList()..sort();
  final List<String> fromProject = used.where(projectEnums.contains).toList()..sort();

  return <String>[
    if (fromSdk.isNotEmpty) ...<String>[
      'import type {',
      for (final String e in fromSdk) '  $e,',
      '} from "@scribe/sdk";',
    ],
    if (fromProject.isNotEmpty) ...<String>[
      'import type {',
      for (final String e in fromProject) '  $e,',
      '} from "${globals.project.generatedAlias}enums.ts";',
    ],
    '',
  ];
}
