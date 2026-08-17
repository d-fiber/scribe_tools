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

/// The line that opens the generated relations section of `tables.ts`.
const String relationsMarkerStart = '// @generated:relations:start';

/// The line that closes it.
const String relationsMarkerEnd = '// @generated:relations:end';

/// The relations section of [file], or an empty string when it has none.
///
/// A missing file and a file without markers answer the same way: both mean no
/// relation type is declared yet, and neither is a failure, since the section is
/// written by a later step of the same run.
Future<String> readRelationsSection(File file) async {
  if (!await file.exists()) return '';

  final String source = await file.readAsString();
  final int start = source.indexOf(relationsMarkerStart);
  final int end = source.indexOf(relationsMarkerEnd);

  return start == -1 || end == -1 ? '' : source.substring(start, end);
}

/// The tables [section] declares a `<X>Relations` type for.
///
/// Read from the section rather than recomputed, because it is the previous
/// run's output that decides what the types are named today.
Set<String> tablesWithRelationsIn(String section, Iterable<String> candidates) => <String>{
  for (final String table in candidates)
    if (section.contains('type ${table.toPascalCase()}Relations =')) table,
};
