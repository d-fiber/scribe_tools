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


import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/base/common.dart';

/// Écrit la liste des pays autorisés dans le dossier généré.
///
/// Le pare-feu lui-même (`api/public/app/_country_firewall.ts`) reste dans le
/// SDK : c'est de la forme, identique pour tous les projets. Seules les valeurs
/// sortent — le SDK les charge par un `await import()` optionnel et retombe sur
/// la liste vide, qui signifie « aucune restriction », exactement le défaut
/// documenté dans `config.yaml`.
Future<void> generateCountryFirewall() async {

  final List<String> countries = <String>[
    ...globals.project.manifest.allowedCountries,
  ]..sort();

  final String bin = kToolName;

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.allowedCountries.writeAsString(
    '// This file is auto-generated do not edit manually.\n'
    '// Run: $bin gen code\n'
    '\n'
    'export const ALLOWED_COUNTRIES: readonly string[] = '
    '[${countries.map((String c) => '"$c"').join(', ')}];\n',
  );

  globals.logger.printStatus('${countries.length} allowed countries → ${globals.project.generatedDirectoryName}/sdk/js/allowed_countries.ts');
}
