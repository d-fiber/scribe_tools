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

import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/commands/gen/code/sql/table_schema.dart';
import 'package:scribe/src/globals.dart' as globals;

/// The lines every file `gen code` writes opens with.
///
/// The binary is named from [kToolName], so a generated file does not carry
/// the name of the project it was generated for.
List<String> generatedHeader() => <String>[
  '// This file is auto-generated do not edit manually.',
  '// Run: $kToolName gen code',
  '',
];

/// The names of the enum types [columns] use, each stripped of its array suffix.
Set<String> enumsUsedBy(Iterable<Col> columns) => <String>{
  for (final Col column in columns)
    if (column.enumName case final String name) name.replaceFirst('[]', ''),
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
