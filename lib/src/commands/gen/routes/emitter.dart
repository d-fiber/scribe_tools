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

import 'discovered_route.dart';
import 'discovered_sink.dart';
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

    final StringBuffer sinks = StringBuffer();
    for (final DiscoveredSink sink in source.sinks) {
      final String module = _bind(sink.file, 'l');
      final String node = sink.node == null ? 'null' : _quote(sink.node!);

      sinks.writeln('  { node: $node, file: ${_quote(sink.file)}, module: $module },');
    }

    final String nodes = source.nodes.map(_quote).join(', ');

    return '$header\n'
        'import type { DiscoveredLogSink, DiscoveredRoute } from "@scribe/sdk";\n'
        '$_imports'
        '\n'
        'export const nodes: readonly string[] = [$nodes];\n'
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
