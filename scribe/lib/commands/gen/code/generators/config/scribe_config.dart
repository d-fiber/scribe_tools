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

import '../../../../../core/file_system_entity/paths.dart';
import '../../../../../core/logger.dart';

// Les alias de chemin de la config du SDK : ils décrivent où le SDK se trouve
// par rapport à lui-même, donc ils ne peuvent pas être recopiés tels quels dans
// la config d'un projet qui vit ailleurs. Tout le reste (les ~30 dépendances
// tierces) est hérité mot pour mot, pour que la version d'une dépendance soit
// déclarée à un seul endroit.
const Set<String> _sdkPathAliases = <String>{
  '@scribe/core/',
  '@scribe/host/',
  '@scribe/protocol/',
  '@scribe/sdk',
  '@scribe/sdk/',
  '@app/',
  '@assets/',
};

/// Écrit les deux cartes d'imports du projet.
///
/// C'est l'inversion de dépendance qui rend le SDK déplaçable : jusqu'ici
/// `scribe/host/deno.json` pointait vers `../../lib/`, donc le SDK devait
/// être le frère du projet. Désormais c'est le projet qui pointe vers le SDK,
/// en absolu, et le SDK n'a plus à savoir qu'un projet existe.
///
/// Deux fichiers parce que les chemins de l'hôte n'existent pas dans le
/// conteneur : `scribe.json` sert à l'éditeur et aux vérifications locales ;
/// `scribe.container.json` est monté puis passé en `--config` par le compose.
///
/// Le nom ne dit pas le runtime : côté projet, rien ne doit trahir avec quoi le
/// framework est implémenté.
///
/// `@scribe/sdk/` (le préfixe qui ouvre l'intérieur du SDK) y figure quand même,
/// parce que cette carte sert AUSSI à compiler l'hôte — en conteneur et dans
/// l'éditeur. Seul le projet n'a aucune raison de s'en servir ; c'est une
/// convention, pas une frontière que la carte peut faire respecter.
Future<void> generateScribeConfig() async {
  const Log log = Log('gen');

  final Map<String, dynamic> sdk = jsonDecode(await Paths.kernel.scribe.host.denoJson.content());
  final Map<String, String> inherited = <String, String>{
    for (final MapEntry<String, dynamic> e in (sdk['imports'] as Map<String, dynamic>).entries)
      if (!_sdkPathAliases.contains(e.key)) e.key: e.value as String,
  };

  final String sdkRoot = Paths.kernel.scribe.host.path;

  await Paths.alchemy.sdk.js.create();

  await Paths.alchemy.sdk.js.scribeJson.writeAsString(
    _render(
      inherited,
      sdk,
      sdkRoot: _asDirectory(sdkRoot),
      projectRoot: _asDirectory(Paths.project.path),
      assetsRoot: _asDirectory(Paths.assets.path),
    ),
  );

  await Paths.alchemy.sdk.js.scribeContainerJson.writeAsString(
    _render(inherited, sdk, sdkRoot: '/app/scribe/host/', projectRoot: '/app/lib/', assetsRoot: '/app/assets/'),
  );

  log.info(
    '${inherited.length} deps inherited → ${Paths.generatedDirectory}/sdk/js/scribe{,.container}.json',
  );
}

String _asDirectory(String path) => path.endsWith(p.separator) ? path : '$path${p.separator}';

String _render(
  Map<String, String> inherited,
  Map<String, dynamic> sdk, {
  required String sdkRoot,
  required String projectRoot,
  required String assetsRoot,
}) {
  final Map<String, dynamic> document = <String, dynamic>{
    'imports': <String, String>{
      ...inherited,
      '@scribe/core/': '${sdkRoot}core/',
      '@scribe/host/': sdkRoot,
      '@scribe/protocol/': '${p.dirname(sdkRoot)}/protocol/',
      '@scribe/sdk': '${p.dirname(sdkRoot)}/sdk/js/mod.ts',
      '@scribe/sdk/': '${p.dirname(sdkRoot)}/sdk/js/',
      '@app/': projectRoot,
      '@assets/': assetsRoot,
      Paths.generatedAlias: './',
      '@generated/': './',
    },
    'lock': false,
    if (sdk['compilerOptions'] != null) 'compilerOptions': sdk['compilerOptions'],
    if (sdk['fmt'] != null) 'fmt': sdk['fmt'],
  };

  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}
