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
import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:fiber_shell/fiber_shell.dart';
import 'package:path/path.dart' as p;


import '../../../core/logger.dart';
import '../../../core/file_system_entity/paths.dart';
import '../../../core/file_system_entity/source.dart';
import '../../../ops/config.dart';
import 'docs_surface.dart';
import 'sections/paths.dart';
import 'sections/servers.dart';
import 'sections/tags.dart';
import 'walker/generated_path.dart';
import 'walker/walker_process.dart';

String _renderHeader(DocsSurface surface) =>
    '''
openapi: 3.1.0

info:
  title: "${surface.title}"
  version: 1.0.0
  description: "${surface.description}"
  x-logo:
    url: /logo-dark.png
    altText: "\${APP_NAME}"
    backgroundColor: "#09090b"''';

const String _components = '''
components:
  schemas:
    Error:
      type: object
      required: [code]
      properties:
        code:
          type: string
        message:
          type: string
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT''';

String _renderDocument({
  required DocsSurface surface,
  required String serverUrl,
  required List<String> tags,
  required List<GeneratedPathEntry> pathEntries,
}) {
  return <String>[
    _renderHeader(surface),
    renderServersSection(serverUrl),
    renderTagsSection(tags),
    _components,
    renderPathsSection(pathEntries),
  ].join('\n\n');
}

Future<void> generateDocs() async {
  const Log log = Log('gen');
  final Directory root = Paths.root;
  final ProjectUrls urls = deriveUrls((await Config.read()).get('URL'));

  final List<DocsSurface> surfaces = discoverSurfaces(root, (await Config.read()).getDocsSurfaces());

  for (final DocsSurface surface in surfaces) {
    final List<String> tags = surfaceTagNames(root, surface.key);
    final String serverUrl = surfaceServerUrl(urls, surface.key);
    final GeneratedPathsDocument doc = await runWalker(root, surface.key);
    validateTags(doc, tags.toSet());

    final String content = _renderDocument(surface: surface, serverUrl: serverUrl, tags: tags, pathEntries: doc.paths);

    final Source yamlFile = Paths.alchemy.docs.surface(surface.key);
    await Paths.alchemy.docs.create();
    await yamlFile.writeAsString('$content\n');

    log.info('${surface.key}: ${tags.length} tags, ${doc.paths.length} paths → ${yamlFile.path}');
  }

  await _writeIndex(surfaces, log);
  await _buildPortal(root, log);
}

/// Construit le portail depuis le manifeste qu'on vient d'ecrire.
///
/// `.infrastructure/docs/` sort entierement de cette commande : les specs, le
/// manifeste, et les variantes statiques qui les affichent.
Future<void> _buildPortal(Directory root, Log log) async {
  final Directory portal = Directory(p.join(root.path, 'scribe/web/developers_docs'));
  final Directory workspace = portal.parent;

  if (!Directory(p.join(workspace.path, 'node_modules')).existsSync()) {
    log.info('portal: installing workspace dependencies (npm ci)...');
    final ShellResult install = await Npm.ci().output(cwd: workspace.path);
    if (install.failed) {
      log.error('portal: npm ci failed — ${install.error}');
    }
  }

  final ShellResult result = await Npm.run().script('build').output(cwd: portal.path);
  if (result.failed) {
    log.error('portal: build failed — ${result.error}');
  }

  log.info('portal: ${Paths.generatedDirectory}/docs/dist/ rebuilt');
}

Future<void> _writeIndex(List<DocsSurface> surfaces, Log log) async {
  final Config config = await Config.read();
  final String appName = config.get('NAME');

  final Map<String, dynamic> manifest = <String, dynamic>{
    'appName': appName,
    'appNameSnake': appName.toSnakeCase(),
    'basePath': '/developers/docs',
    'surfaces': <Map<String, String>>[
      for (final DocsSurface surface in surfaces)
        <String, String>{
          'key': surface.key,
          'title': _substitute(surface.title, appName),
          'description': _substitute(surface.description, appName),
          'spec': '${surface.key}.yaml',
        },
    ],
  };

  await Paths.alchemy.docs.indexJson.writeAsString('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  log.info('${surfaces.length} surface(s) → ${Paths.alchemy.docs.indexJson.path}');
}

String _substitute(String template, String appName) =>
    template.replaceAll(r'${APP_NAME}', appName).replaceAll(r'${APP_NAME_SNAKE}', appName.toSnakeCase());
