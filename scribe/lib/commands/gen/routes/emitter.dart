import 'package:path/path.dart' as p;

import 'discovered_route.dart';
import 'discovered_source.dart';

const String _projectAlias = '@app/';
const String _projectDirectory = 'lib';

String specifierOf(String file) {
  final String relative = p.relative(file, from: _projectDirectory);
  return '$_projectAlias${p.split(relative).join('/')}';
}

class RoutesEmitter {
  RoutesEmitter(this.source);

  final DiscoveredSource source;

  final Map<String, String> _bindings = <String, String>{};
  final StringBuffer _imports = StringBuffer();

  String render(String header) {
    final StringBuffer entries = StringBuffer();

    for (final DiscoveredRoute route in source.routes) {
      final String module = _bind(route.file, 'r');
      final String branches = route.branches.map((String file) => _bind(file, 'b')).join(', ');

      entries.writeln('  {');
      entries.writeln('    node: ${_quote(route.node)},');
      entries.writeln('    path: ${_quote(route.path)},');
      entries.writeln('    file: ${_quote(route.file)},');
      entries.writeln('    module: $module,');
      entries.writeln('    branches: [$branches],');
      entries.writeln('  },');
    }

    final String nodes = source.nodes.map(_quote).join(', ');

    return '$header\n'
        'import type { DiscoveredRoute } from "@scribe/sdk";\n'
        '$_imports'
        '\n'
        'export const nodes: readonly string[] = [$nodes];\n'
        '\n'
        'export const routes: readonly DiscoveredRoute[] = [\n'
        '$entries'
        '];\n';
  }

  String _bind(String file, String prefix) {
    final String? existing = _bindings[file];
    if (existing != null) return existing;

    final String binding = '_$prefix${_bindings.length}';
    _bindings[file] = binding;
    _imports.writeln('import * as $binding from "${specifierOf(file)}";');
    return binding;
  }

  String _quote(String value) => '"$value"';
}
