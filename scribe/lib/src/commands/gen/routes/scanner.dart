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

import 'package:path/path.dart' as p;

import 'conventions.dart';
import 'discovered_route.dart';
import 'discovered_source.dart';
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;

class RouteScanner {
  RouteScanner(this.projectRoot);

  final String projectRoot;

  final List<DiscoveredRoute> _routes = <DiscoveredRoute>[];
  final Map<String, String> _claimed = <String, String>{};

  static Future<DiscoveredSource> discover() async {
    final Directory src = globals.project.sources;
    if (!src.existsSync()) {
      throwToolExit('[gen:routes] ${src.path} is missing: create lib/src/ first.');
    }

    return scan(src, globals.project.directory.path);
  }

  static DiscoveredSource scan(Directory src, String projectRoot) {
    final RouteScanner scanner = RouteScanner(projectRoot);

    final List<Directory> nodes = src
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((Directory directory) => !p.basename(directory.path).startsWith(Conventions.privatePrefix))
        .toList()
      ..sort((Directory a, Directory b) => a.path.compareTo(b.path));

    for (final Directory node in nodes) {
      scanner._walk(node, p.basename(node.path), '/', const <String>[]);
    }

    return DiscoveredSource(
      nodes: nodes.map((Directory node) => p.basename(node.path)).toList(),
      routes: scanner._routes,
    );
  }

  void _walk(Directory directory, String node, String prefix, List<String> branches) {
    final List<FileSystemEntity> entries = directory.listSync(followLinks: false)
      ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));

    _rejectObsoleteNode(entries, node);

    final List<String> inherited = _inherit(entries, branches);
    final Set<String> directories = entries
        .whereType<Directory>()
        .map((Directory child) => p.basename(child.path))
        .toSet();

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
      _claim(node, path, file.path);
      _routes.add(
        DiscoveredRoute(
          node: node,
          path: path,
          file: _relative(file.path),
          branches: inherited,
        ),
      );
    }

    for (final Directory child in entries.whereType<Directory>()) {
      final String name = p.basename(child.path);
      if (name.startsWith(Conventions.privatePrefix)) continue;
      _walk(child, node, Conventions.join(prefix, name), inherited);
    }
  }

  void _rejectObsoleteNode(List<FileSystemEntity> entries, String node) {
    final File? obsolete = entries.whereType<File>().where((File file) {
      return Conventions.isObsoleteNode(p.basename(file.path));
    }).firstOrNull;

    if (obsolete == null) return;

    throwToolExit(
      '[gen:routes] ${_relative(obsolete.path)} is obsolete: "$node/" carries its caller by name now. '
      'Delete the file, and move anything it declared to _middleware.ts.',
    );
  }

  List<String> _inherit(List<FileSystemEntity> entries, List<String> branches) {
    final File? middleware = entries.whereType<File>().where((File file) {
      return Conventions.isMiddleware(p.basename(file.path));
    }).firstOrNull;

    if (middleware == null) return branches;
    return <String>[...branches, _relative(middleware.path)];
  }

  void _claim(String node, String path, String file) {
    final String key = '$node:$path';
    final String? previous = _claimed[key];
    if (previous != null) {
      throwToolExit(
        '[gen:routes] ${_relative(file)} and $previous both answer /$node$path.',
      );
    }
    _claimed[key] = _relative(file);
  }

  String _relative(String path) => p.relative(path, from: projectRoot);
}
