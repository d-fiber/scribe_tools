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

import 'package:change_case/change_case.dart';
import 'package:path/path.dart' as p;

class DocsSurface {
  const DocsSurface({required this.key, required this.title, required this.description});

  final String key;
  final String title;
  final String description;
}

const Map<String, DocsSurface> _known = <String, DocsSurface>{
  'admin': DocsSurface(
    key: 'admin',
    title: r'${APP_NAME} Admin API',
    description: r'Internal API for ${APP_NAME} admin panel. All routes require VPN access.',
  ),
  'app': DocsSurface(
    key: 'app',
    title: r'${APP_NAME} App API',
    description: r'Public API for the ${APP_NAME} app.',
  ),
};

List<DocsSurface> discoverSurfaces(Directory root, Map<String, Map<String, String>> declared) {
  final Directory publicApis = Directory(p.join(root.path, 'scribe/host/api/public'));
  if (!publicApis.existsSync()) return const <DocsSurface>[];

  final List<String> keys = publicApis
      .listSync(followLinks: false)
      .whereType<Directory>()
      .map((Directory entry) => p.basename(entry.path))
      .where((String key) => !key.startsWith('_'))
      .toList()
    ..sort();

  return <DocsSurface>[for (final String key in keys) _resolve(key, declared[key])];
}

/// La prose du projet gagne, le defaut du framework sinon, la derivation en
/// dernier recours.
DocsSurface _resolve(String key, Map<String, String>? declared) {
  final DocsSurface fallback = _known[key] ?? _derive(key);
  if (declared == null) return fallback;

  return DocsSurface(
    key: key,
    title: declared['title'] ?? fallback.title,
    description: declared['description'] ?? fallback.description,
  );
}

DocsSurface _derive(String key) => DocsSurface(
  key: key,
  title: '\${APP_NAME} ${key.toPascalCase()} API',
  description: 'API surface `$key` of \${APP_NAME}.',
);
