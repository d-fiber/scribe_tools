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
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

final RegExp _createTable = RegExp(
  r'create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp _references = RegExp(r'\breferences\s+public\.(\w+)', caseSensitive: false);

/// Which table points at which, read from the foreign keys of the whole schema.
class RelationGraph {
  /// Holds the foreign keys read off the whole schema, in both directions.
  const RelationGraph({required this.outbound, required this.inbound, required this._toOne});

  /// For each table, the tables it holds a foreign key to.
  final Map<String, Set<String>> outbound;

  /// For each table, the tables that hold a foreign key to it.
  final Map<String, Set<String>> inbound;

  final Map<String, bool> _toOne;

  /// Whether [parent] can have more than one [child].
  ///
  /// A foreign key declared on a primary key or a unique column can only ever
  /// match one row, so the relation is rendered as a single object rather than
  /// a list. Anything unknown counts as many, which is the safe way round: a
  /// list that turns out to hold one row still type-checks.
  bool isMany(String child, String parent) => !(_toOne['$child|$parent'] ?? false);

  /// The tables of [exposed] that something in [exposed] points at, sorted.
  ///
  /// Both ends have to be exposed. A relation that crosses the boundary between
  /// the framework and the project is left out entirely, because neither
  /// generated file imports the other side's row type.
  List<MapEntry<String, Set<String>>> parentsAmong(Set<String> exposed) =>
      inbound.entries
          .where(
            (MapEntry<String, Set<String>> entry) => exposed.contains(entry.key) && entry.value.any(exposed.contains),
          )
          .toList()
        ..sort((MapEntry<String, Set<String>> a, MapEntry<String, Set<String>> b) => a.key.compareTo(b.key));
}

/// Reads the foreign keys of the framework SQL and the project SQL into a graph.
Future<RelationGraph> scanRelationGraph() async {
  final Map<String, Set<String>> outbound = <String, Set<String>>{};
  final Map<String, Set<String>> inbound = <String, Set<String>>{};
  final Map<String, bool> toOne = <String, bool>{};

  Future<void> parse(File file) async {
    final String sql = await file.readAsString();

    for (final RegExpMatch table in _createTable.allMatches(sql)) {
      final String name = table.group(1)!;
      final String body = table.group(2)!;
      outbound.putIfAbsent(name, () => <String>{});

      for (final RegExpMatch reference in _references.allMatches(body)) {
        final String target = reference.group(1)!;
        outbound[name]!.add(target);
        inbound.putIfAbsent(target, () => <String>{}).add(name);
        toOne['$name|$target'] = _declaresAtMostOne(body, reference.start);
      }
    }
  }

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, parse);
  }
  await walkSqlFiles(globals.project.init, parse);

  return RelationGraph(outbound: outbound, inbound: inbound, toOne: toOne);
}

/// Whether the line of [body] holding [offset] makes the key unique.
///
/// The whole line is read rather than the match alone: `primary key` and
/// `unique` sit beside the reference, not inside it.
bool _declaresAtMostOne(String body, int offset) {
  final int start = body.lastIndexOf('\n', offset) + 1;
  final int end = body.indexOf('\n', offset);
  final String line = body.substring(start, end == -1 ? body.length : end).toLowerCase();

  return line.contains('primary key') || line.contains(' unique');
}
