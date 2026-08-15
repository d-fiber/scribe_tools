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

import 'dart:io';

import 'package:change_case/change_case.dart';

import '../../../../core/logger.dart';
import '../../../../core/paths/infra_files.dart';
import '../../../../core/paths/tree.g.dart';
import '../../../../ops/config.dart';
import '../../sql_scanner.dart';

final RegExp _exposedRe = RegExp(r'''\bfrom<[^>]+>\(\s*this\.db,\s*["'](\w+)["']''');

final RegExp _createTableRe = RegExp(
  r'create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp _referencesRe = RegExp(r'\breferences\s+public\.(\w+)', caseSensitive: false);

// Version kernel-only : un seul fichier cible (kernel tables.ts), filtré sur
// les tables exposées dans ce fichier. Voir scripts/cli/lib/commands/gen/code/
// relations/relations.dart pour la version unifiée qui patche aussi le
// tables.ts project.
List<String> _renderRelationTypes(
  Map<String, Set<String>> outbound,
  Map<String, bool> isOne,
  Set<String> exposed,
  List<MapEntry<String, Set<String>>> parents,
) {
  bool many(String child, String parent) => !(isOne['$child|$parent'] ?? false);

  final List<String> lines = <String>[];

  for (final MapEntry<String, Set<String>> entry in parents) {
    final String parent = entry.key;
    final List<String> kids = entry.value.where(exposed.contains).toList()..sort();
    lines.add('export type ${parent.toPascalCase()}Relations = {');

    for (final String child in kids) {
      final bool childMany = many(child, parent);
      final List<String> nested =
          (outbound[child] ?? <String>{}).where((String t) => t != parent && exposed.contains(t)).toList()..sort();

      if (nested.isNotEmpty) {
        lines.add('  $child: {');
        lines.add('    row: ${child.toPascalCase()}Row;');
        lines.add('    many: $childMany;');
        lines.add('    relations: {');
        for (final String n in nested) {
          lines.add('      $n: { row: ${n.toPascalCase()}Row; many: false };');
        }
        lines.add('    };');
        lines.add('  };');
      } else {
        lines.add('  $child: { row: ${child.toPascalCase()}Row; many: $childMany };');
      }
    }

    lines.add('};\n');
  }

  return lines;
}

// Les Row types référencés par les types rendus — l'import de `gen/relations.ts`
// s'en déduit, plutôt que d'être recalculé à partir de `parents`/`kids`/`nested`.
final RegExp _rowTypeRe = RegExp(r'\b[A-Z][A-Za-z0-9]*Row\b');

List<String> _renderRelationsFile(String bin, List<String> types) {
  final Set<String> rows = <String>{
    for (final String line in types)
      for (final RegExpMatch m in _rowTypeRe.allMatches(line)) m.group(0)!,
  };
  final List<String> sortedRows = rows.toList()..sort();

  return <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
    if (sortedRows.isNotEmpty) ...<String>[
      'import type {',
      for (final String row in sortedRows) '  $row,',
      '} from "./rows.ts";',
      '',
    ],
    ...types,
  ];
}

Future<void> generateRelations() async {
  const Log log = Log('gen');

  final Map<String, Set<String>> outbound = <String, Set<String>>{};
  final Map<String, Set<String>> inbound = <String, Set<String>>{};

  final Map<String, bool> isOne = <String, bool>{};

  Future<void> parseSql(File file) async {
    final String sql = await file.readAsString();
    for (final RegExpMatch tableMatch in _createTableRe.allMatches(sql)) {
      final String table = tableMatch.group(1)!;
      final String body = tableMatch.group(2)!;
      outbound.putIfAbsent(table, () => <String>{});

      for (final RegExpMatch refMatch in _referencesRe.allMatches(body)) {
        final String ref = refMatch.group(1)!;
        outbound[table]!.add(ref);
        inbound.putIfAbsent(ref, () => <String>{}).add(table);

        final int refIdx = refMatch.start;
        final int lineStart = body.lastIndexOf('\n', refIdx) + 1;
        final int lineEnd = body.indexOf('\n', refIdx);
        final String line = body.substring(lineStart, lineEnd == -1 ? body.length : lineEnd).toLowerCase();
        final bool one = line.contains('primary key') || line.contains(' unique');
        isOne['$table|$ref'] = one;
      }
    }
  }

  // Kernel-only : jamais lib/db/init/ (voir generateEnums()).
  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, parseSql);
  }

  List<MapEntry<String, Set<String>>> parentsFor(Set<String> exposed) {
    return inbound.entries.where((MapEntry<String, Set<String>> e) {
      return exposed.contains(e.key) && e.value.any((String c) => exposed.contains(c));
    }).toList()
      ..sort((MapEntry<String, Set<String>> a, MapEntry<String, Set<String>> b) => a.key.compareTo(b.key));
  }

  // Kernel-only : une seule cible, et elle est 100 % générée des deux côtés —
  // les tables exposées se lisent dans gen/tables.ts (les méthodes écrites
  // juste avant par generateTables()), la sortie part dans gen/relations.ts,
  // réécrit en entier. Plus aucun marqueur à patcher. Voir la version cli pour
  // le second passage côté project, qui en garde, lui.
  final FoundationFunctionsDependenciesDatabaseRest rest = InfraFiles.tree.scribe.host.dependencies.database.rest;
  final String source = await rest.gen.tablesTs.readAsString();
  final Set<String> exposed = <String>{for (final RegExpMatch m in _exposedRe.allMatches(source)) m.group(1)!};
  final List<MapEntry<String, Set<String>>> parents = parentsFor(exposed);
  final List<String> types = _renderRelationTypes(outbound, isOne, exposed, parents);

  final String bin = Config.read().get('NAME').toSnakeCase();
  await rest.gen.relationsTs.writeAsString(_renderRelationsFile(bin, types).join('\n'));

  log.info(
    'kernel: ${parents.length} Relations types generated: '
    '${parents.map((MapEntry<String, Set<String>> e) => e.key).join(", ")}',
  );
}
