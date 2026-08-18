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
import 'package:yaml/yaml.dart';

import '../core/exception.dart';
import '../core/logger.dart';
import '../core/paths/infra_files.dart';
import '../core/template/merge.dart';
import '../core/template/render.dart';
import 'config.dart';
import 'dependencies.dart';
import 'hardware.dart';
import 'sizing_rules.dart';

const Log _log = Log('sizing');

class Sizing {
  static Map<String, String> resolve(Hardware hardware) {
    final SizingRules rules = SizingRules(hardware);
    final Map<String, String> values = rules.resolve();

    _log.info('detected hardware: $hardware');
    _log.info(
      'api x${rules.apiReplicas}, rest x${rules.restReplicas}, storage x${rules.storageReplicas}, '
      'db ${values['db_mem_limit']} (shared_buffers ${values['db_shared_buffers']}), '
      'pool ${values['rest_db_pool']}/instance',
    );
    _log.info('active profiles: ${rules.profiles.isEmpty ? 'the socle alone' : rules.profiles}');

    if (hardware.memoryGb < 4 || hardware.cores < 2) {
      _log.warn('very small machine (${hardware.toString()}), the stack may not start.');
    }

    return <String, String>{...values, ..._overrides()};
  }

  static Map<String, String> _overrides() {
    final File file = InfraFiles.tree.scribe.ops.docker.sizingOverrideYaml;
    if (!file.existsSync()) return const <String, String>{};

    final dynamic document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return const <String, String>{};

    final Map<String, String> overrides = <String, String>{
      for (final MapEntry<dynamic, dynamic> entry in document.entries) '${entry.key}': '${entry.value}',
    };
    _log.warn('${overrides.length} value(s) forced by docker/sizing.override.yaml');
    return overrides;
  }
}

class ComposeTemplates {
  static Future<List<File>> render(Map<String, String> values, {String? appName}) async {
    final Directory target = InfraFiles.tree.alchemy.ops.docker.directory;
    if (!target.existsSync()) target.createSync(recursive: true);

    final Config config = Config.read();
    final String name = appName ?? config.get('NAME');
    final Map<String, String> resolved = <String, String>{
      ...values,
      'app_name': name,
      'app_name_snake': name.toSnakeCase(),
      'sdk_root': './scribe',
      'alchemy_dir': p.basename(InfraFiles.tree.alchemy.directory.path),
    };

    final Dependencies dependencies = Dependencies.load();
    final List<Dependency> active = dependencies.active;
    _logSelection(dependencies, active);

    final List<File> sources = <File>[
      InfraFiles.tree.scribe.templates.ops.docker.dockerComposeYaml,
      InfraFiles.tree.scribe.templates.ops.docker.resourcesYaml,
      InfraFiles.tree.scribe.templates.ops.docker.replicasYaml,
      InfraFiles.tree.scribe.templates.ops.docker.tuningYaml,
    ];

    final List<File> rendered = <File>[];
    for (final File source in sources) {
      final String template = source.uri.pathSegments.last;
      rendered.add(
        await _renderOne(source, resolved, target, dependencies.fragmentsFor(template, active)),
      );
    }

    int position = 1;
    for (final Dependency dependency in active) {
      for (final YamlFragment overlay in dependency.fragmentsFor(overlayTemplate)) {
        rendered.insert(
          position++,
          await _write(overlayFileName(overlay.label), overlayBase, resolved, target, <YamlFragment>[overlay]),
        );
      }
    }

    return rendered;
  }

  static void _logSelection(Dependencies dependencies, List<Dependency> active) {
    final List<String> dropped = <String>[
      for (final Dependency dependency in dependencies.all)
        if (!active.contains(dependency)) dependency.path,
    ];
    if (dropped.isEmpty) {
      _log.info('${active.length} dependency(ies) mounted: all of them');
      return;
    }
    _log.info('${active.length} dependency(ies) mounted, dropped: ${dropped.join(', ')}');
  }

  static Future<File> _renderOne(
    File source,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments,
  ) async {
    if (!source.existsSync()) {
      throw CliException('Template introuvable : ${source.path}');
    }

    return _write(source.uri.pathSegments.last, await source.readAsString(), values, target, fragments);
  }

  static Future<File> _write(
    String name,
    String source,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments,
  ) async {
    final File destination = File('${target.path}/$name');
    await destination.writeAsString(renderTemplate(name, mergeYamlDocuments(source, fragments), values));
    return destination;
  }
}
