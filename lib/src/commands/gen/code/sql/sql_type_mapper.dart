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

import 'package:change_case/change_case.dart';

import '../../sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

final Map<String, String> composites = <String, String>{};

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

class MappedType {
  MappedType(this.ts, [this.enumName]);

  final String ts;
  final String? enumName;
}

MappedType mapPublicType(String name) {
  if (composites.containsKey(name)) return MappedType(composites[name]!);
  final String ts = enumOverrides[name] ?? name.toPascalCase();
  return MappedType(ts, ts);
}

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
