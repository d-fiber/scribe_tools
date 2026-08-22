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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/routes/conventions.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_route.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_sink.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_source.dart';
import 'package:scribe_tools/src/commands/gen/routes/route_claims.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Turns the file tree of `lib/src/` into the routes it declares.
///
/// The tree is the routing table: a directory of `lib/src/` is a node, a `.ts`
/// file under it is a route at the path its own place spells, and a directory
/// whose name starts with `_` is invisible to both.
///
/// Everything is sorted before it is read, so the table only changes when the
/// tree does. The order the file system hands entries back in would otherwise
/// end up in the generated file.
class RouteScanner {
  /// Scans into a table whose paths are written relative to [projectRoot].
  RouteScanner(this.projectRoot);

  /// The directory every path in the result is written relative to.
  final String projectRoot;

  final List<DiscoveredRoute> _routes = <DiscoveredRoute>[];
  final RouteClaims _claims = RouteClaims();

  /// Scans the current project's `lib/src/`.
  ///
  /// Throws a [ToolExit] when there is no `lib/src/` to scan.
  static Future<DiscoveredSource> discover() async {
    final Directory src = globals.project.sources;
    if (!src.existsSync()) {
      throwToolExit('[gen:routes] ${src.path} is missing: create lib/src/ first.');
    }

    return scan(src, globals.project.directory.path);
  }

  /// Scans [src] as a `lib/src/`, writing paths relative to [projectRoot].
  static DiscoveredSource scan(Directory src, String projectRoot) {
    final RouteScanner scanner = RouteScanner(projectRoot);
    final List<Directory> nodes = _nodesOf(src);

    for (final Directory node in nodes) {
      scanner._walk(node, p.basename(node.path), '/', const <String>[]);
    }

    return DiscoveredSource(
      nodes: <String>[for (final Directory node in nodes) p.basename(node.path)],
      routes: scanner._routes,
      sinks: scanner._sinksOf(src, nodes),
    );
  }

  /// The `_log.ts` files of the project root and of each node, in that order.
  ///
  /// Only those two places are looked at. A `_log.ts` deeper in a node would
  /// read as though logging could be scoped to a subtree, which nothing
  /// delivers on: the host routes by node and knows nothing finer.
  List<DiscoveredSink> _sinksOf(Directory src, List<Directory> nodes) {
    final List<DiscoveredSink> sinks = <DiscoveredSink>[];

    final File root = File(p.join(src.parent.path, '${Conventions.logName}${Conventions.sourceExtension}'));
    if (root.existsSync()) {
      sinks.add(DiscoveredSink(node: null, file: _relative(root.path)));
    }

    for (final Directory node in nodes) {
      final File own = File(p.join(node.path, '${Conventions.logName}${Conventions.sourceExtension}'));
      if (!own.existsSync()) continue;

      sinks.add(DiscoveredSink(node: p.basename(node.path), file: _relative(own.path)));
    }

    return sinks;
  }

  /// The directories of [src] that are nodes, sorted, private ones left out.
  static List<Directory> _nodesOf(Directory src) =>
      src
          .listSync(followLinks: false)
          .whereType<Directory>()
          .where((Directory directory) => !Conventions.isPrivate(p.basename(directory.path)))
          .toList()
        ..sort((Directory a, Directory b) => a.path.compareTo(b.path));

  void _walk(Directory directory, String node, String prefix, List<String> branches) {
    final List<FileSystemEntity> entries = directory.listSync(followLinks: false)
      ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));

    _rejectObsoleteNode(entries, node);

    final List<String> inherited = _inherit(entries, branches);
    _collectRoutes(entries, directory: directory, node: node, prefix: prefix, branches: inherited);
    _descend(entries, node: node, prefix: prefix, branches: inherited);
  }

  /// Adds one route per routable file of [entries].
  ///
  /// A file named `index` answers the directory's own path rather than a path
  /// of its own.
  ///
  /// Throws a [ToolExit] when a file and a directory of the same name would
  /// answer the same path, which the tree cannot express.
  void _collectRoutes(
    List<FileSystemEntity> entries, {
    required Directory directory,
    required String node,
    required String prefix,
    required List<String> branches,
  }) {
    final Set<String> directories = <String>{
      for (final Directory child in entries.whereType<Directory>()) p.basename(child.path),
    };

    for (final File file in entries.whereType<File>()) {
      final String basename = p.basename(file.path);
      if (!Conventions.isRoutable(basename)) continue;

      final String name = Conventions.withoutExtension(basename);
      if (directories.contains(name)) {
        throwToolExit(
          '[gen:routes] ${_relative(file.path)} and ${_relative(p.join(directory.path, name))}/ '
          'both claim ${Conventions.join(prefix, name)}: keep one of the two.',
        );
      }

      final String path = name == Conventions.indexName ? prefix : Conventions.join(prefix, name);
      _claims.claim(node: node, path: path, file: _relative(file.path));
      _routes.add(DiscoveredRoute(node: node, path: path, file: _relative(file.path), branches: branches));
    }
  }

  void _descend(
    List<FileSystemEntity> entries, {
    required String node,
    required String prefix,
    required List<String> branches,
  }) {
    for (final Directory child in entries.whereType<Directory>()) {
      final String name = p.basename(child.path);
      if (Conventions.isPrivate(name)) continue;

      _walk(child, node, Conventions.join(prefix, name), branches);
    }
  }

  /// Refuses a `_node.ts` left over from when a node had to name its caller.
  ///
  /// Throws a [ToolExit]: the directory's own name carries that now, so the
  /// file is not merely useless, it describes something that no longer happens.
  void _rejectObsoleteNode(List<FileSystemEntity> entries, String node) {
    final File? obsolete = entries
        .whereType<File>()
        .where((File file) => Conventions.isObsoleteNode(p.basename(file.path)))
        .firstOrNull;

    if (obsolete == null) return;

    throwToolExit(
      '[gen:routes] ${_relative(obsolete.path)} is obsolete: "$node/" carries its caller by name now. '
      'Delete the file, and move anything it declared to _middleware.ts.',
    );
  }

  /// [branches] plus this directory's own `_middleware.ts`, when it has one.
  ///
  /// Middleware accumulates downwards: a route runs every one between the node
  /// and itself, outermost first, which is the order this list keeps.
  List<String> _inherit(List<FileSystemEntity> entries, List<String> branches) {
    final File? middleware = entries
        .whereType<File>()
        .where((File file) => Conventions.isMiddleware(p.basename(file.path)))
        .firstOrNull;

    return middleware == null ? branches : <String>[...branches, _relative(middleware.path)];
  }

  String _relative(String path) => p.relative(path, from: projectRoot);
}
