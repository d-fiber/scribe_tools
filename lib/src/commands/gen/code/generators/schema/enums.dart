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
import 'package:file/file.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/project_enums.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/enum_scan.dart';
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Rewrites the project's `enums.ts`, and names what it declared.
///
/// The returned names are what the table generator routes its imports with: an
/// enum is declared by the framework or by the project, never by both, so a
/// name that is missing from this set comes from the SDK.
///
/// The framework's own enums are only read. Their TypeScript ships with the
/// framework, so nothing is written for them here.
Future<Set<String>> generateEnums() async {
  final List<ParsedEnum> fromFramework = await scanEnums(kernelSqlRoots());
  globals.logger.printStatus('${fromFramework.length} kernel enums read from the SDK');

  final List<ParsedEnum> fromProject = await scanEnums(<Directory>[globals.project.init]);
  if (fromProject.isEmpty) return <String>{};

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.enums.writeAsString(renderProjectEnums(fromProject).join('\n'));

  globals.logger.printStatus(
    '${fromProject.length} project enums → ${globals.project.generatedDirectoryName}/sdk/js/enums.ts',
  );

  return <String>{for (final ParsedEnum parsed in fromProject) parsed.name.toPascalCase()};
}
