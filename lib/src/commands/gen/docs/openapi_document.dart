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

import 'package:file/file.dart';
import 'package:scribe_tools/src/commands/gen/docs/docs_index.dart';
import 'package:scribe_tools/src/commands/gen/docs/docs_surface.dart';
import 'package:scribe_tools/src/commands/gen/docs/openapi_skeleton.dart';
import 'package:scribe_tools/src/commands/gen/docs/portal_build.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/servers.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/tags.dart';
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';
import 'package:scribe_tools/src/commands/gen/docs/walker/walker_process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/scribe_manifest.dart';

/// Rewrites one OpenAPI document per documented surface, then the portal.
///
/// The routes are read by a walker running over the TypeScript, not by parsing
/// it here: the endpoints declare their shape in code, and the code is the only
/// thing that can be trusted to still be true.
Future<void> generateDocs() async {
  final Directory root = globals.project.directory;
  final ProjectUrls urls = deriveUrls(globals.project.manifest.apiUrl);
  final List<DocsSurface> surfaces = discoverSurfaces(root, globals.project.manifest.docsSurfaces);

  for (final DocsSurface surface in surfaces) {
    await _writeSurface(surface, root: root, urls: urls);
  }

  await writeDocsIndex(surfaces);
  await buildPortal(root);
}

Future<void> _writeSurface(DocsSurface surface, {required Directory root, required ProjectUrls urls}) async {
  final List<String> tags = surfaceTagNames(root, surface.key);
  final GeneratedPathsDocument walked = await runWalker(root, surface.key);
  validateTags(walked, tags.toSet());

  final String document = renderOpenApiDocument(
    surface: surface,
    serverUrl: surfaceServerUrl(urls, surface.key),
    tags: tags,
    pathEntries: walked.paths,
  );

  await globals.project.generated.docs.create();
  final File file = globals.project.generated.docs.surface(surface.key);
  await file.writeAsString('$document\n');

  globals.logger.printStatus(
    '${surface.key}: ${tags.length} tags and ${walked.paths.length} paths, written to ${file.path}',
  );
}
