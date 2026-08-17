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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/commands/gen/sql_scanner.dart';

final RegExp _enumType = RegExp(
  r'create\s+type\s+public\.(\w+)\s+as\s+enum\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp _quotedValue = RegExp(r"'([^']+)'");

/// One `CREATE TYPE ... AS ENUM` found in the SQL.
class ParsedEnum {
  const ParsedEnum(this.name, this.values);

  /// The type's name in Postgres, as it was declared.
  final String name;

  /// Its values, in the order Postgres will order them.
  final List<String> values;
}

/// The enums declared under [roots], sorted by name.
///
/// Only files whose name contains `enum` are opened. That is a convention, not
/// a rule of Postgres: it keeps the scan off every table definition in the
/// tree, at the cost of missing an enum someone hides in `tables.sql`.
Future<List<ParsedEnum>> scanEnums(Iterable<Directory> roots) async {
  final List<ParsedEnum> found = <ParsedEnum>[];

  Future<void> collect(File file) async {
    if (!p.basename(file.path).contains('enum')) return;

    final String sql = await file.readAsString();
    for (final RegExpMatch match in _enumType.allMatches(sql)) {
      found.add(
        ParsedEnum(
          match.group(1)!,
          _quotedValue.allMatches(match.group(2)!).map((RegExpMatch value) => value.group(1)!).toList(),
        ),
      );
    }
  }

  for (final Directory root in roots) {
    await walkSqlFiles(root, collect);
  }

  found.sort((ParsedEnum a, ParsedEnum b) => a.name.compareTo(b.name));
  return found;
}
