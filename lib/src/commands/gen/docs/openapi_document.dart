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
  final ProjectUrls urls = deriveUrls(globals.project.manifest.url);
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

  globals.logger.printStatus('${surface.key}: ${tags.length} tags, ${walked.paths.length} paths → ${file.path}');
}
