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
import 'package:scribe_tools/src/commands/gen/code/relations/relation_graph.dart';

/// The `<X>Relations` type of every parent in [parents].
///
/// Only tables of [exposed] appear, on both ends of every relation. Each child
/// carries one level of nesting, the tables it points at in turn, and no
/// more: a deeper walk would need cycle detection for a depth nobody queries.
List<String> renderRelationTypes(
  RelationGraph graph,
  Set<String> exposed,
  List<MapEntry<String, Set<String>>> parents,
) {
  final List<String> lines = <String>[];

  for (final MapEntry<String, Set<String>> entry in parents) {
    final String parent = entry.key;
    final List<String> children = entry.value.where(exposed.contains).toList()..sort();

    lines.add('type ${parent.toPascalCase()}Relations = {');
    for (final String child in children) {
      lines.addAll(_child(graph, exposed, child: child, parent: parent));
    }
    lines.add('};\n');
  }

  return lines;
}

List<String> _child(RelationGraph graph, Set<String> exposed, {required String child, required String parent}) {
  final bool many = graph.isMany(child, parent);
  final String row = '${child.toPascalCase()}Row';

  final List<String> nested =
      (graph.outbound[child] ?? const <String>{}).where((String table) => table != parent && exposed.contains(table)).toList()
        ..sort();

  if (nested.isEmpty) {
    return <String>['  $child: { row: $row; many: $many };'];
  }

  return <String>[
    '  $child: {',
    '    row: $row;',
    '    many: $many;',
    '    relations: {',
    for (final String table in nested) '      $table: { row: ${table.toPascalCase()}Row; many: false };',
    '    };',
    '  };',
  ];
}
