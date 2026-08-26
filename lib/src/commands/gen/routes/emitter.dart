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

import 'package:path/path.dart' as p;

import 'package:scribe_tools/src/commands/gen/routes/discovered_route.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_sink.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_source.dart';
import 'package:scribe_tools/src/nodes.dart';

const String _projectAlias = '@app/';
const String _projectDirectory = 'lib';

/// [file] as the generated table imports it, through the project's own alias.
String specifierOf(String file) {
  final String relative = p.relative(file, from: _projectDirectory);
  return '$_projectAlias${p.split(relative).join('/')}';
}

/// Writes the TypeScript table the host reads its routes from.
class RoutesEmitter {
  /// Writes out [source], which is what one scan found, for the nodes [declared].
  RoutesEmitter(this.source, {required this.declared});

  /// The scan being written out.
  final DiscoveredSource source;

  /// The nodes the manifest arms, which are what the worker mounts.
  ///
  /// They come from the manifest and not from the folders the scan walked: a
  /// directory arms nothing on its own, and what the worker mounts has to be
  /// what the gateway was rendered for.
  final List<ProjectNode> declared;

  final Map<String, String> _bindings = <String, String>{};
  final StringBuffer _imports = StringBuffer();

  /// The whole generated module, [header] first.
  ///
  /// A file imported twice is bound once: a route and its middleware often name
  /// the same module, and a second import of it would not compile.
  String render(String header) {
    final StringBuffer entries = StringBuffer();

    for (final DiscoveredRoute route in source.routes) {
      final String module = _bind(route.file, 'r');
      final String branches = route.branches.map((String file) => _bind(file, 'b')).join(', ');

      entries
        ..writeln('  {')
        ..writeln('    node: ${_quote(route.node)},')
        ..writeln('    path: ${_quote(route.path)},')
        ..writeln('    file: ${_quote(route.file)},')
        ..writeln('    module: $module,')
        ..writeln('    branches: [$branches],')
        ..writeln('  },');
    }

    final StringBuffer sinks = StringBuffer();
    for (final DiscoveredSink sink in source.sinks) {
      final String module = _bind(sink.file, 'l');
      final String node = sink.node == null ? 'null' : _quote(sink.node!);

      sinks.writeln('  { node: $node, file: ${_quote(sink.file)}, module: $module },');
    }

    final String nodes = declared
        .map((ProjectNode node) => '{ name: ${_quote(node.name)}, public: ${node.facesOutward} }')
        .join(', ');

    return '$header\n'
        'import type { DeclaredNode, DiscoveredLogSink, DiscoveredRoute } from "@scribe/sdk";\n'
        '$_imports'
        '\n'
        'export const nodes: readonly DeclaredNode[] = [$nodes];\n'
        '\n'
        'export const routes: readonly DiscoveredRoute[] = [\n'
        '$entries'
        '];\n'
        '\n'
        'export const logSinks: readonly DiscoveredLogSink[] = [\n'
        '$sinks'
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
