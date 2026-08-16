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

import 'package:change_case/change_case.dart';

import '../../sql_scanner.dart';
import 'package:scribe/src/globals.dart' as globals;

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
