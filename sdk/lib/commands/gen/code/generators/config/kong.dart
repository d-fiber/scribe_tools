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

import '../../../../../core/logger.dart';
import '../../../../../core/paths/infra_files.dart';
import '../../../../../core/template/merge.dart';
import '../../../../../core/template/render.dart';
import '../../../../../ops/config.dart';
import '../../../../../ops/dependencies.dart';
import '../../../../../ops/env_file.dart';


const String _denyAllOrigin = 'https://cors.disabled.invalid';

const List<String> _corsPlaceholders = <String>[
  'admin_cors_origins',
  'storage_cors_origins',
  'app_cors_origins',
  'realtime_cors_origins',
];

const Map<String, String> _keyFieldByConsumer = <String, String>{
  'app': 'APP_KEYS',
  'admin': 'ADMIN_APP_KEYS',
};

Future<void> generateKong() async {
  const Log log = Log('gen');
  final Config config = Config.read();

  final List<String> origins = config.getPath(<String>['api', 'config', 'origins']);
  final Map<String, List<String>> keysByConsumer = <String, List<String>>{
    for (final MapEntry<String, String> entry in _keyFieldByConsumer.entries) entry.key: _readKeys(entry.value),
  };

  final Map<String, String> values = <String, String>{
    'app_key_consumers': consumerBlock(keysByConsumer),
    for (final String placeholder in _corsPlaceholders) placeholder: originsBlock(origins),
  };

  final Dependencies dependencies = Dependencies.load();
  final List<Dependency> active = dependencies.active;

  final String template = mergeYamlDocuments(
    await InfraFiles.tree.scribe.ops.gateway.kongYml.readAsString(),
    dependencies.fragmentsFor('kong.yml', active),
  );
  final File output = InfraFiles.tree.alchemy.ops.gateway.kongYml;

  await output.parent.create(recursive: true);
  await output.writeAsString(
    '# This file is auto-generated do not edit manually.\n'
    '# Run: koko-kernel gen code\n'
    '${renderTemplate('kong.yml', template, values)}',
  );

  final String counts = keysByConsumer.entries
      .map((MapEntry<String, List<String>> entry) => '${entry.value.length} ${entry.key} key(s)')
      .join(', ');
  log.info('$counts, ${origins.length} origin(s) → ${InfraFiles.tree.alchemy.ops.gateway.kongYml.path}');
}

List<String> _readKeys(String field) =>
    EnvFile.read(field).split(',').map((String key) => key.trim()).where((String key) => key.isNotEmpty).toList();

String consumerBlock(Map<String, List<String>> keysByConsumer) {
  final List<String> lines = <String>[];
  for (final MapEntry<String, List<String>> entry in keysByConsumer.entries) {
    lines.add('- username: ${entry.key}');
    if (entry.value.isEmpty) continue;
    lines.add('  keyauth_credentials:');
    for (final String key in entry.value) {
      lines.add('    - key: $key');
    }
  }
  return lines.join('\n');
}

String originsBlock(List<String> origins) {
  final List<String> effective = origins.isEmpty ? <String>[_denyAllOrigin] : origins;
  return <String>['origins:', for (final String origin in effective) '  - "$origin"'].join('\n');
}
