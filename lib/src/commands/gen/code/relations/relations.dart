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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/emit_relations.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/relation_graph.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/relations_markers.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

final RegExp _exposedTable = RegExp(r'''\bnew\s+TypedQueryBuilder<[^>]+>\(\s*this\.db,\s*["'](\w+)["']''');

/// Rewrites the relations section of the generated `tables.ts`.
///
/// This runs after the table generator and reads what it wrote: the tables a
/// relation may name are the ones `tables.ts` exposes a query method for, so
/// they are read back out of the file rather than recomputed.
///
/// Nothing happens when the project has no generated `tables.ts`, which is the
/// case for a project that declares no table of its own.
///
/// Throws a [ToolExit] when the file is there but has lost its markers, since
/// there is then no way to tell the generated section from hand-written code.
Future<void> generateRelations() async {
  final File tables = globals.project.generated.sdk.rest.tables;
  if (!await tables.exists()) return;

  final RelationGraph graph = await scanRelationGraph();
  final String source = await tables.readAsString();

  final Set<String> exposed = <String>{
    for (final RegExpMatch match in _exposedTable.allMatches(source)) match.group(1)!,
  };
  final List<MapEntry<String, Set<String>>> parents = graph.parentsAmong(exposed);

  await tables.writeAsString(_withSectionReplaced(source, parents, graph, exposed, path: tables.path));

  globals.logger.printStatus(
    'project: ${parents.length} Relations types generated: '
    '${parents.map((MapEntry<String, Set<String>> entry) => entry.key).join(", ")}',
  );
}

String _withSectionReplaced(
  String source,
  List<MapEntry<String, Set<String>>> parents,
  RelationGraph graph,
  Set<String> exposed, {
  required String path,
}) {
  final int start = source.indexOf(relationsMarkerStart);
  final int end = source.indexOf(relationsMarkerEnd);
  if (start == -1 || end == -1) {
    throwToolExit('Markers not found in $path.');
  }

  final List<String> section = <String>[
    '$relationsMarkerStart\n',
    ...renderRelationTypes(graph, exposed, parents),
    relationsMarkerEnd,
  ];

  return source.substring(0, start) + section.join('\n') + source.substring(end + relationsMarkerEnd.length);
}
