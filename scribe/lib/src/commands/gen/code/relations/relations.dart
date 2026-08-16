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
import 'relations_markers.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/base/common.dart';

final RegExp _projectExposedRe = RegExp(r'''\bnew\s+TypedQueryBuilder<[^>]+>\(\s*this\.db,\s*["'](\w+)["']''');

final RegExp _createTableRe = RegExp(
  r'create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp _referencesRe = RegExp(r'\breferences\s+public\.(\w+)', caseSensitive: false);

// Un run par cible (kernel gen/relations.ts, project tables.ts), chacune
// filtrée sur SON PROPRE ensemble de tables exposées uniquement — pas de
// relation cross-boundary pour l'instant (une relation project→kernel ou
// kernel→project est simplement omise du bloc généré, aucun des deux fichiers
// n'importe le Row type de l'autre côté pour une relation). À ajouter plus
// tard si besoin, une fois la migration des consommateurs project actée
// (voir .claude/lib/extensions/manifest/global.md).
//
// `exported` : côté kernel les types vivent dans leur propre module et doivent
// donc être exportés ; côté project ils restent locaux au tables.ts qui les
// porte.
List<String> _renderRelationTypes(
  Map<String, Set<String>> outbound,
  Map<String, bool> isOne,
  Set<String> exposed,
  List<MapEntry<String, Set<String>>> parents, {
  required bool exported,
}) {
  bool many(String child, String parent) => !(isOne['$child|$parent'] ?? false);

  final List<String> lines = <String>[];
  final String keyword = exported ? 'export type' : 'type';

  for (final MapEntry<String, Set<String>> entry in parents) {
    final String parent = entry.key;
    final List<String> kids = entry.value.where(exposed.contains).toList()..sort();
    lines.add('$keyword ${parent.toPascalCase()}Relations = {');

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

Future<void> generateRelations() async {

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

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, parseSql);
  }
  await walkSqlFiles(globals.project.init, parseSql);

  List<MapEntry<String, Set<String>>> parentsFor(Set<String> exposed) {
    return inbound.entries.where((MapEntry<String, Set<String>> e) {
      return exposed.contains(e.key) && e.value.any((String c) => exposed.contains(c));
    }).toList()..sort((MapEntry<String, Set<String>> a, MapEntry<String, Set<String>> b) => a.key.compareTo(b.key));
  }

  void report(String label, List<MapEntry<String, Set<String>>> parents) {
    globals.logger.printStatus(
      '$label: ${parents.length} Relations types generated: '
      '${parents.map((MapEntry<String, Set<String>> e) => e.key).join(", ")}',
    );
  }

  // Kernel : fichier dédié, 100 % généré, réécrit en entier. Les tables
  // exposées se lisent dans gen/tables.ts (les méthodes générées juste avant
  // par generateTables()), la sortie part dans gen/relations.ts — les deux
  // fichiers sont donc générés, aucun marqueur à patcher.

  // Project : toujours une section entre marqueurs dans son tables.ts, qui
  // porte aussi les méthodes et les imports (voir tables.dart).
  final File projectTablesTs = globals.project.generated.sdk.rest.tables;
  if (!await projectTablesTs.exists()) return;

  final String projectSource = await projectTablesTs.readAsString();
  final Set<String> projectExposed = <String>{
    for (final RegExpMatch m in _projectExposedRe.allMatches(projectSource)) m.group(1)!,
  };
  final List<MapEntry<String, Set<String>>> projectParents = parentsFor(projectExposed);
  final List<String> projectLines = <String>[
    '$relationsMarkerStart\n',
    ..._renderRelationTypes(outbound, isOne, projectExposed, projectParents, exported: false),
    relationsMarkerEnd,
  ];

  final int si = projectSource.indexOf(relationsMarkerStart);
  final int ei = projectSource.indexOf(relationsMarkerEnd);
  if (si == -1 || ei == -1) {
    throwToolExit('Markers not found in ${projectTablesTs.path}.');
  }

  await projectTablesTs.writeAsString(
    projectSource.substring(0, si) + projectLines.join('\n') + projectSource.substring(ei + relationsMarkerEnd.length),
  );
  report('project', projectParents);
}
