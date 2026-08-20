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
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

final RegExp _createTable = RegExp(
  r'create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp _references = RegExp(r'\breferences\s+public\.(\w+)', caseSensitive: false);

/// Which table points at which, read from the foreign keys of the whole schema.
class RelationGraph {
  const RelationGraph({required this.outbound, required this.inbound, required Map<String, bool> toOne})
    : _toOne = toOne;

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
            (MapEntry<String, Set<String>> entry) =>
                exposed.contains(entry.key) && entry.value.any(exposed.contains),
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
