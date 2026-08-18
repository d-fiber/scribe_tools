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

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:scribe/src/globals.dart' as globals;

/// The aliases of the framework's own configuration that a project must not inherit.
///
/// They say where the framework sits relative to itself, so they mean something
/// else once the project is somewhere else. Everything besides them, the third
/// party dependencies and their versions, is copied word for word, so that a
/// version is declared in one place only.
const Set<String> _frameworkPathAliases = <String>{
  '@scribe/core/',
  '@scribe/foundation/',
  '@scribe/host/',
  '@scribe/protocol/',
  '@scribe/sdk',
  '@scribe/sdk/',
  '@app/',
  '@assets/',
};

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
/// copy the container is given: the host's paths do not exist inside the
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
  final String above = p.dirname(frameworkRoot);

  final Map<String, dynamic> document = <String, dynamic>{
    'imports': <String, String>{
      ...inherited,
      '@scribe/core/': '${frameworkRoot}core/',
      '@scribe/foundation/': '${frameworkRoot}packages/foundation/',
      '@scribe/host/': frameworkRoot,
      '@scribe/protocol/': '$above/protocol/',
      '@scribe/sdk': '$above/sdk/js/mod.ts',
      '@scribe/sdk/': '$above/sdk/js/',
      '@app/': projectRoot,
      '@assets/': assetsRoot,
      globals.project.generatedAlias: './',
      '@generated/': './',
    },
    'lock': false,
    if (frameworkConfig['compilerOptions'] != null) 'compilerOptions': frameworkConfig['compilerOptions'],
    if (frameworkConfig['fmt'] != null) 'fmt': frameworkConfig['fmt'],
  };

  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

/// [path] with a trailing separator, which an import map prefix needs.
String asDirectory(String path) => path.endsWith(p.separator) ? path : '$path${p.separator}';
