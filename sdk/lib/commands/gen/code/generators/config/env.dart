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
import 'package:yaml/yaml.dart';

import '../../../../../core/logger.dart';
import '../../../../../core/paths/infra_files.dart';
import '../../../../../ops/config.dart';
import '../seeds/smtp_accounts.dart';

// Names that can't be inferred from naming convention alone.
const Set<String> _booleanVars = {'VERIFY_JWT'};
const Set<String> _optionalVars = {
  'JWT_SECRET',
  'APP_DEEPLINK_SCHEME',
  'APP_IOS_STORE_URL',
  'APP_ANDROID_STORE_URL',
  'TWILIO_ACCOUNT_SID',
  'TWILIO_AUTH_TOKEN',
  'TWILIO_MESSAGE_SERVICE_SID',
  'GOOGLE_CLIENT_ID',
  'GOOGLE_CLIENT_SECRET',
  'GOOGLE_ADDITIONAL_CLIENT_IDS',
  'APPLE_CLIENT_ID',
  'APPLE_CLIENT_SECRET',
  'APPLE_ADDITIONAL_CLIENT_IDS',
};
const Map<String, String> _defaults = {'PORT': '3000'};

final RegExp _envVarName = RegExp(r'^[A-Z][A-Z0-9_]*$');

/// Les noms de variables d'env declares pour [service] dans les fichiers
/// [compose].
///
/// Ignore toute cle qui n'est pas un nom de variable d'env valide : un
/// docker-compose non rendu porte des placeholders `{{...}}` que le parseur
/// YAML interprete comme des cles complexes, et un tel nom produirait un
/// accesseur TypeScript syntaxiquement invalide.
List<String> readComposeEnvNames(List<File> compose, String service) {
  final List<String> names = <String>[];
  for (final File source in compose) {
    final dynamic doc = loadYaml(source.readAsStringSync());
    final dynamic env = doc['services'][service]?['environment'];
    if (env is! YamlMap) continue;
    for (final dynamic key in env.keys) {
      final String name = key.toString();
      if (_envVarName.hasMatch(name)) names.add(name);
    }
  }
  return names;
}

const List<String> _smtpFields = <String>['HOST', 'PORT', 'USER', 'PASS'];

/// Les accesseurs SMTP des comptes du SDK, derives de [foundationSmtpAccounts].
///
/// Ils ne se lisent plus depuis `docker-compose.smtp.yaml` : ce fichier est un
/// template rendu au lancement, ses valeurs n'y sont pas encore substituees.
List<String> smtpEnvNames() => <String>[
  for (final String account in foundationSmtpAccounts.toList()..sort())
    for (final String field in _smtpFields) 'SMTP_${account.toUpperCase()}_$field',
];

List<String> _requiredStringGetter(String name) => [
  '  static get $name(): string {',
  '    return this.get("$name");',
  '  }',
];

List<String> _numberGetter(String name) => [
  '  static get $name(): number {',
  '    return parseInt(this.get("$name"));',
  '  }',
];

List<String> _numberWithDefaultGetter(String name, String fallback) => [
  '  static get $name(): number {',
  '    return parseInt(Deno.env.get("$name") ?? "$fallback");',
  '  }',
];

List<String> _arrayGetter(String name) => [
  '  static get $name(): string[] {',
  '    return this.get("$name")',
  '      .split(",")',
  '      .map((k) => k.trim())',
  '      .filter(Boolean);',
  '  }',
];

List<String> _booleanGetter(String name) => [
  '  static get $name(): boolean {',
  '    return Deno.env.get("$name") === "true";',
  '  }',
];

List<String> _optionalStringGetter(String name) => [
  '  static get $name(): string | undefined {',
  '    return Deno.env.get("$name");',
  '  }',
];

List<String> _getterFor(String name) {
  if (_booleanVars.contains(name)) return _booleanGetter(name);
  if (_optionalVars.contains(name)) return _optionalStringGetter(name);
  final String? fallback = _defaults[name];
  if (fallback != null) return _numberWithDefaultGetter(name, fallback);
  if (name.endsWith('_KEYS')) return _arrayGetter(name);
  if (name.endsWith('PORT')) return _numberGetter(name);
  return _requiredStringGetter(name);
}

Future<void> generateEnv() async {
  const Log log = Log('gen');

  final String bin = Config.read().get('NAME').toSnakeCase();
  final List<String> names = <String>{
    ...readComposeEnvNames(<File>[InfraFiles.tree.scribe.ops.docker.dockerComposeYaml], 'api'),
    ...smtpEnvNames(),
  }.toList();

  final List<String> lines = <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
    'export class Env {',
    '  protected static get(name: string): string {',
    '    const value = Deno.env.get(name);',
    '    if (!value)',
    '      throw new Error("Missing required environment variable: " + name);',
    '    return value;',
    '  }',
  ];

  for (final String varName in names) {
    lines.add('');
    lines.addAll(_getterFor(varName));
  }

  lines.add('}');

  await InfraFiles.tree.scribe.host.envTs.writeAsString('${lines.join('\n')}\n');
  log.info('${names.length} env accessors → env.ts');
}
