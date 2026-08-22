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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';

final RegExp _enumType = RegExp(r'create\s+type\s+public\.(\w+)\s+as\s+enum\s*\(([\s\S]*?)\);', caseSensitive: false);

final RegExp _quotedValue = RegExp(r"'([^']+)'");

/// One `CREATE TYPE ... AS ENUM` found in the SQL.
class ParsedEnum {
  /// Holds the enum [name] and the [values] it was declared with.
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
