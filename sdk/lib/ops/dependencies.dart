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

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/exception.dart';
import '../core/paths/infra_files.dart';
import '../core/template/merge.dart';

const String manifestName = 'scribe.yaml';
const String fragmentDirectory = 'ops';
const String overlayTemplate = 'overlay.yaml';
const String overlayBase = 'name: "{{app_name_snake}}"\nservices:\n';

String overlayFileName(String path) => 'overlay.${path.replaceAll('/', '-')}.yaml';

class DependencyInfra {
  const DependencyInfra({
    required this.services,
    required this.profile,
    required this.gateway,
    required this.env,
  });

  final List<String> services;
  final String? profile;
  final List<String> gateway;
  final List<String> env;
}

class Dependency {
  const Dependency({
    required this.path,
    required this.name,
    required this.title,
    required this.optional,
    required this.requires,
    required this.infra,
    required this.sql,
    required this.protocol,
    required this.export,
    required this.routes,
    required this.directory,
  });

  final String path;
  final String name;
  final String title;
  final bool optional;
  final List<String> requires;
  final DependencyInfra infra;
  final String? sql;
  final String? protocol;
  final String? export;
  final List<String> routes;
  final Directory directory;

  /// The files this module's slices of [template] would be read from.
  ///
  /// A package groups its ops by subject, so `ops/valkery/docker-compose.yaml`
  /// counts as much as `ops/docker-compose.yaml`. None of them is required to
  /// exist: a module contributes to the templates it has something to say about
  /// and to no others.
  List<File> fragments(String template) {
    final Directory ops = Directory(p.join(directory.path, fragmentDirectory));
    if (!ops.existsSync()) return const <File>[];

    final List<File> found = <File>[File(p.join(ops.path, template))];
    for (final Directory subject in ops.listSync().whereType<Directory>()) {
      found.add(File(p.join(subject.path, template)));
    }

    return found.where((File file) => file.existsSync()).toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
  }

  /// This module's slices of [template], one per subject that declares one.
  List<YamlFragment> fragmentsFor(String template) => <YamlFragment>[
    for (final File file in fragments(template)) YamlFragment(_labelOf(file), file.readAsStringSync()),
  ];

  /// The name written into the merged document above a fragment's block.
  ///
  /// A fragment that sits in a subject directory names the subject too, so a
  /// reader of the generated compose can tell `foundation/valkery` from
  /// `foundation/queue`.
  String _labelOf(File file) {
    final String subject = p.basename(file.parent.path);
    return subject == fragmentDirectory ? path : '$path/$subject';
  }
}

class Dependencies {
  const Dependencies(this.all);

  final List<Dependency> all;

  /// Every module under [roots], both host roots by default.
  ///
  /// There are two roots and not one because a module can live in either of two
  /// repositories: `host/dependencies/` holds what the framework owns, and
  /// `host/packages/` is the submodule where the mountable packages live. A
  /// module's address stays relative to the root that carries it, so `db` sits
  /// under `foundation` while `auth` stays `security/auth`.
  ///
  /// A root that does not exist yields nothing rather than failing, since a
  /// clone without `--recurse-submodules` has no `host/packages/` at all.
  static Dependencies load({List<Directory>? roots}) {
    final List<Directory> searched = roots ?? _defaultRoots();
    final List<Dependency> found = <Dependency>[];

    for (final Directory modules in searched) {
      if (!modules.existsSync()) continue;

      found.addAll(
        modules
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((File file) => p.basename(file.path) == manifestName)
            .map((File file) => _read(file, modules)),
      );
    }

    found.sort((Dependency a, Dependency b) => a.path.compareTo(b.path));

    return Dependencies(found);
  }

  static List<Directory> _defaultRoots() => <Directory>[
    InfraFiles.tree.scribe.host.dependencies.directory,
    InfraFiles.tree.scribe.host.packages.directory,
  ];

  List<Dependency> get active => selected(configuredSelection());

  Dependency? byPath(String path) {
    for (final Dependency dependency in all) {
      if (dependency.path == path) return dependency;
    }
    return null;
  }

  List<Dependency> selected(List<String> wanted) {
    if (wanted.isEmpty) return all;

    final Set<String> keep = <String>{
      for (final Dependency dependency in all)
        if (!dependency.optional) dependency.path,
    };

    for (final String path in wanted) {
      if (byPath(path) == null) {
        throw CliException(
          'config.yaml: unknown dependency "$path". The '
          'known ones are ${all.map((Dependency d) => d.path).join(', ')}.',
        );
      }
      keep.add(path);
    }

    int size = 0;
    while (size != keep.length) {
      size = keep.length;
      for (final String path in keep.toList()) {
        keep.addAll(byPath(path)!.requires);
      }
    }

    return all.where((Dependency dependency) => keep.contains(dependency.path)).toList();
  }

  List<YamlFragment> fragmentsFor(String template, List<Dependency> active) => <YamlFragment>[
    for (final Dependency dependency in active) ...dependency.fragmentsFor(template),
  ];
}

List<String> configuredSelection() {
  final File file = InfraFiles.tree.configYaml;
  if (!file.existsSync()) return const <String>[];

  final dynamic document = loadYaml(file.readAsStringSync());
  if (document is! YamlMap) return const <String>[];

  final Object? value = document['dependencies'];
  if (value is! YamlList) return const <String>[];

  return value
      .map((dynamic entry) => entry.toString().trim())
      .where((String entry) => entry.isNotEmpty)
      .toList();
}

Dependency _read(File manifest, Directory modules) {
  final dynamic document = loadYaml(manifest.readAsStringSync());
  if (document is! YamlMap) {
    throw CliException('${manifest.path}: manifest is not a YAML mapping');
  }

  final dynamic infra = document['ops'];
  final YamlMap infraMap = infra is YamlMap ? infra : YamlMap();

  return Dependency(
    path: p.relative(manifest.parent.path, from: modules.path),
    name: _string(document, 'name') ?? p.basename(manifest.parent.path),
    title: _string(document, 'title') ?? '',
    optional: document['optional'] is bool ? document['optional'] as bool : true,
    requires: _strings(document, 'requires'),
    infra: DependencyInfra(
      services: _strings(infraMap, 'services'),
      profile: _string(infraMap, 'profile'),
      gateway: _strings(infraMap, 'gateway'),
      env: _strings(infraMap, 'env'),
    ),
    sql: _string(document, 'sql'),
    protocol: _string(document, 'protocol'),
    export: _string(document, 'export'),
    routes: _strings(document, 'routes'),
    directory: manifest.parent,
  );
}

String? _string(YamlMap map, String key) {
  final Object? value = map[key];
  return value is String ? value : null;
}

List<String> _strings(YamlMap map, String key) {
  final Object? value = map[key];
  if (value is! YamlList) return const <String>[];
  return value.map((dynamic entry) => entry.toString()).toList();
}
