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
import 'package:file/file.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/enum_scan.dart';
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The TypeScript body of every `create type ... as (...)` the SQL declares.
///
/// Filled by [loadComposites] and read by [mapPublicType]. It is empty until
/// that run, so a mapping asked for too early answers `unknown` rather than
/// failing, which is why nothing calls it before the scan.
final Map<String, String> composites = <String, String>{};

/// The name of every `create type ... as enum (...)` the SQL declares, framework and project alike.
///
/// Filled by [loadEnums] and read by [mapPublicType], the same way [composites] is: a
/// `public.<name>` this set does not carry and [composites] does not carry either is neither a
/// composite nor an enum, a Postgres `DOMAIN` among the possible reasons, and mapping it as one
/// would emit an import for a TypeScript symbol nothing generates.
final Set<String> enumNames = <String>{};

/// The TypeScript type to write for a Postgres enum, where the generated one is wrong.
///
/// Empty, and the mapping falls back on the enum's own generated name.
const Map<String, String> enumOverrides = <String, String>{};

final RegExp _compositeRe = RegExp(r'create\s+type\s+public\.(\w+)\s+as\s+\(([\s\S]*?)\);', caseSensitive: false);

List<String> _parseCompositeFields(String body) {
  final List<String> fields = <String>[];
  for (final String raw in body.split('\n')) {
    String line = raw.trim();
    if (line.endsWith(',')) line = line.substring(0, line.length - 1);
    if (line.isEmpty) continue;

    final int space = line.indexOf(RegExp(r'\s'));
    if (space == -1) continue;
    final String colName = line.substring(0, space);
    final String sqlType = line.substring(space + 1).trim();

    fields.add('$colName: ${mapSqlType(sqlType).ts}');
  }
  return fields;
}

/// Reads every composite type of the socle and of the project into [composites].
///
/// It runs once before any table is mapped, since a column of a composite type
/// has no TypeScript to be written as until its fields are known.
Future<void> loadComposites() async {
  final Map<String, String> bodies = <String, String>{};

  Future<void> collect(File file) async {
    final String sql = await file.readAsString();
    for (final RegExpMatch match in _compositeRe.allMatches(sql)) {
      bodies[match.group(1)!] = match.group(2)!;
    }
  }

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, collect);
  }
  await walkSqlFiles(globals.project.init, collect);

  composites.clear();
  for (final MapEntry<String, String> entry in bodies.entries) {
    composites[entry.key] = '{ ${_parseCompositeFields(entry.value).join('; ')} }';
  }
}

/// A SQL type as TypeScript writes it.
class MappedType {
  /// Maps to [ts], naming [enumName] when the SQL type was an enum.
  MappedType(this.ts, [this.enumName]);

  /// The TypeScript type, without the `| null` a nullable column adds.
  final String ts;

  /// The Postgres enum this came from, null when it came from anything else.
  final String? enumName;
}

/// Reads every enum of the socle and of the project into [enumNames].
///
/// It runs once before any table is mapped, the same as [loadComposites]: a scan that ran only
/// over the project would leave every framework enum reading as an unclassifiable type the
/// moment a project's own table carried one.
Future<void> loadEnums() async {
  final List<ParsedEnum> fromFramework = await scanEnums(kernelSqlRoots());
  final List<ParsedEnum> fromProject = await scanEnums(<Directory>[globals.project.init]);

  enumNames
    ..clear()
    ..addAll(fromFramework.map((ParsedEnum parsed) => parsed.name))
    ..addAll(fromProject.map((ParsedEnum parsed) => parsed.name));
}

/// The TypeScript for `public.<name>`, which is a composite, an enum, or neither.
///
/// A name that is neither, a Postgres `DOMAIN` among the possible reasons, maps to `unknown`
/// rather than being guessed at as an enum: the symbol an enum's name resolves to is never
/// generated for one, and importing it would break the build of every file that does.
MappedType mapPublicType(String name) {
  if (composites.containsKey(name)) return MappedType(composites[name]!);
  if (enumNames.contains(name)) {
    final String ts = enumOverrides[name] ?? name.toPascalCase();
    return MappedType(ts, ts);
  }
  return MappedType('unknown');
}

/// The TypeScript for the SQL type [raw], however it is spelled.
MappedType mapSqlType(String raw) {
  final String t = raw.toLowerCase().trim();

  if (t.endsWith('[]')) {
    final MappedType inner = mapSqlType(raw.substring(0, raw.length - 2).trim());
    return MappedType('${inner.ts}[]', inner.enumName);
  }

  if (t.startsWith('public.')) return mapPublicType(t.substring(7));

  if (t == 'uuid' || t.startsWith('varchar') || t == 'text' || t.startsWith('char(') || t == 'char') {
    return MappedType('string');
  }

  if (const <String>[
    'bigint',
    'int8',
    'integer',
    'int4',
    'int',
    'int2',
    'smallint',
    'serial',
    'bigserial',
  ].contains(t)) {
    return MappedType('number');
  }

  if (t.startsWith('float') ||
      t == 'double precision' ||
      t.startsWith('numeric') ||
      t.startsWith('decimal') ||
      t == 'real') {
    return MappedType('number');
  }

  if (t == 'boolean' || t == 'bool') return MappedType('boolean');

  if (t == 'timestamptz' || t.startsWith('timestamp') || t == 'date' || t.startsWith('time')) {
    return MappedType('string');
  }

  if (t == 'jsonb' || t == 'json') return MappedType('Record<string, unknown>');

  return MappedType('unknown');
}
