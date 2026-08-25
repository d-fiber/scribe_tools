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

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/globals.dart' as globals;

/// The aliases of the framework's own configuration that a project must not inherit.
///
/// They say where the framework sits relative to itself, so they mean something
/// else once the project is somewhere else. Everything besides them, the third
/// party dependencies and their versions, is copied word for word, so that a
/// version is declared in one place only.
const Set<String> _frameworkPathAliases = <String>{
  '@scribe/alchemy',
  '@scribe/alchemy/',
  '@scribe/alchemy/body',
  '@scribe/alchemy/http',
  '@scribe/alchemy/observe',
  '@scribe/alchemy/route',
  '@scribe/alchemy/server',
  '@scribe/alchemy/test',
  '@scribe/protocol/',
  '@scribe/public/',
  '@scribe/sdk',
  '@scribe/sdk/',
  '@app/',
  '@assets/',
};

/// The layers a project may name, each one a directory under `engine/`.
///
/// They are aliases and not files because a project reaches into a layer by path,
/// the way the framework's own members do. The checkout keeps each layer's own
/// visibility to itself: those declarations say which layer may reach which, and
/// a project is outside that graph, so it gets all of them.
const List<String> _layers = <String>['contracts', 'runtime', 'kernel', 'embedder', 'testing', 'shell'];

/// The packages the framework carries, reached by name like the layers.
const List<String> _packages = <String>[
  'audience',
  'auth',
  'dynamic_links',
  'foundation',
  'realtime',
  'remote_configs',
  'search',
  'storage',
];

/// The third party imports of [frameworkConfig], its own path aliases removed.
Map<String, String> inheritedImports(Map<String, dynamic> frameworkConfig) {
  final Map<String, dynamic> imports = frameworkConfig['imports'] as Map<String, dynamic>;

  return <String, String>{
    for (final MapEntry<String, dynamic> entry in imports.entries)
      if (!_frameworkPathAliases.contains(entry.key)) entry.key: entry.value as String,
  };
}

/// One import map, as the JSON text it is written to disk as.
///
/// The three roots are what changes between the copy the editor reads and the
/// copy the container is given: the engine's paths do not exist inside the
/// container, so the same map cannot serve both.
///
/// `@scribe/sdk/`, which opens the inside of the SDK, is in the map even though
/// a project has no reason to reach through it. The map also compiles the host
/// itself, and the host does. Keeping a project out of there is a convention,
/// not something an import map can enforce.
String renderImportMap(
  Map<String, dynamic> frameworkConfig,
  Map<String, String> inherited, {
  required String frameworkRoot,
  required String projectRoot,
  required String assetsRoot,
}) {
  final String engine = '${frameworkRoot}engine/';

  final Map<String, dynamic> document = <String, dynamic>{
    'imports': <String, String>{
      ...inherited,
      '@scribe/alchemy': '${engine}alchemy/mod.ts',
      '@scribe/alchemy/': '${engine}alchemy/',
      '@scribe/alchemy/body': '${engine}alchemy/api/body/mod.ts',
      '@scribe/alchemy/http': '${engine}alchemy/http/mod.ts',
      '@scribe/alchemy/observe': '${engine}alchemy/observe/mod.ts',
      '@scribe/alchemy/route': '${engine}alchemy/api/route/mod.ts',
      '@scribe/alchemy/server': '${engine}alchemy/api/server/mod.ts',
      '@scribe/alchemy/test': '${engine}alchemy/test/mod.ts',
      for (final String layer in _layers) '@scribe/$layer/': '$engine$layer/',
      for (final String package in _packages) '@scribe/$package/': '${frameworkRoot}packages/$package/',
      '@scribe/protocol/': '${frameworkRoot}protocol/',
      '@scribe/public/': '${frameworkRoot}public/',
      '@scribe/sdk': '${frameworkRoot}sdk/js/mod.ts',
      '@scribe/sdk/': '${frameworkRoot}sdk/js/',
      '@app/': projectRoot,
      '@assets/': assetsRoot,
      globals.project.generatedAlias: './',
      '@generated/': './',
    },
    if (frameworkConfig['compilerOptions'] != null) 'compilerOptions': frameworkConfig['compilerOptions'],
    if (frameworkConfig['fmt'] != null) 'fmt': frameworkConfig['fmt'],
  };

  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

/// [path] with a trailing separator, which an import map prefix needs.
String asDirectory(String path) => path.endsWith(p.separator) ? path : '$path${p.separator}';
