import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/exception.dart';
import '../../../core/file_system_entity/paths.dart';
import 'conventions.dart';
import 'discovered_route.dart';
import 'discovered_source.dart';

class RouteScanner {
  RouteScanner(this.projectRoot);

  final String projectRoot;

  final List<DiscoveredRoute> _routes = <DiscoveredRoute>[];
  final Map<String, String> _claimed = <String, String>{};

  static Future<DiscoveredSource> discover() async {
    final Directory src = Paths.project.src.directory;
    if (!src.existsSync()) {
      throw CliException('[gen:routes] ${src.path} is missing: create lib/src/ first.');
    }

    return scan(src, Paths.root.path);
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
        throw CliException(
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

    throw CliException(
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
      throw CliException(
        '[gen:routes] ${_relative(file)} and $previous both answer /$node$path.',
      );
    }
    _claimed[key] = _relative(file);
  }

  String _relative(String path) => p.relative(path, from: projectRoot);
}
