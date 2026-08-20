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
import 'package:scribe_tools/src/commands/gen/code/generators/schema/enum_scan.dart';

/// The lines of the project's `enums.ts`: one TypeScript enum per Postgres one.
///
/// `enumValues` is re-exported rather than redeclared, so this file is a
/// complete import point on its own: a caller reaches every enum and the helper
/// through it, without having to know which SQL root each name came from.
List<String> renderProjectEnums(List<ParsedEnum> enums) => <String>[
  ...generatedHeader(),
  'export { enumValues } from "@scribe/core/contracts/enums.ts";',
  '',
  for (final ParsedEnum parsed in enums) ...<String>[
    'export enum ${parsed.name.toPascalCase()} {',
    for (final String value in parsed.values) '  ${value.toUpperCase()} = "$value",',
    '}',
    '',
  ],
];
