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
