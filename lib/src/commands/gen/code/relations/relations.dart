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
  if (!tables.existsSync()) return;

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
