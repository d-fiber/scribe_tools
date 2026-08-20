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
