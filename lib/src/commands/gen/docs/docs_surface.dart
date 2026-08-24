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

import 'package:change_case/change_case.dart';
import 'package:path/path.dart' as p;

/// One documented surface, and the prose its OpenAPI document opens with.
class DocsSurface {
  /// Holds the surface [key], titled [title], described by [description].
  const DocsSurface({required this.key, required this.title, required this.description});

  /// The surface's key, which is the name of the directory it is served from.
  final String key;

  /// The document's title, `${APP_NAME}` left in for the portal to substitute.
  final String title;

  /// The document's opening paragraph, `${APP_NAME}` left in the same way.
  final String description;
}

const Map<String, DocsSurface> _known = <String, DocsSurface>{
  'admin': DocsSurface(
    key: 'admin',
    title: r'${APP_NAME} Admin API',
    description: r'Internal API for ${APP_NAME} admin panel. All routes require VPN access.',
  ),
  'app': DocsSurface(key: 'app', title: r'${APP_NAME} App API', description: r'Public API for the ${APP_NAME} app.'),
};

/// Every surface the framework at [root] serves, with the prose [declared] gives it.
///
/// The list comes from the tree rather than from a table here, so a surface
/// added to the framework is documented without this file changing. A directory
/// whose name starts with `_` is not one.
///
/// The project's own prose wins, the framework's default comes next, and a
/// title derived from the key is the last resort.
List<DocsSurface> discoverSurfaces(Directory root, Map<String, Map<String, String>> declared) {
  final Directory publicApis = Directory(p.join(root.path, 'scribe/engine/api/public'));
  if (!publicApis.existsSync()) return const <DocsSurface>[];

  final List<String> keys =
      publicApis
          .listSync(followLinks: false)
          .whereType<Directory>()
          .map((Directory entry) => p.basename(entry.path))
          .where((String key) => !key.startsWith('_'))
          .toList()
        ..sort();

  return <DocsSurface>[for (final String key in keys) _resolve(key, declared[key])];
}

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
