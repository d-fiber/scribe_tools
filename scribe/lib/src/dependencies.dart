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

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;

const String manifestName = 'scribe.yaml';

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
}

class Dependencies {
  const Dependencies(this.all);

  final List<Dependency> all;

  static Dependencies load({Directory? root}) {
    final Directory modules = root ?? globals.fs.directory(globals.project.sdk.hostDependencies.path);
    if (!modules.existsSync()) return const Dependencies(<Dependency>[]);

    final List<Dependency> found = modules
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((File file) => p.basename(file.path) == manifestName)
        .map((File file) => _read(file, modules))
        .toList()
      ..sort((Dependency a, Dependency b) => a.path.compareTo(b.path));

    return Dependencies(found);
  }

  List<Dependency> get active => selected(globals.project.manifest.dependencies);

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
        throwToolExit(
          'config.yaml: unknown dependency "$path" — '
          'known ones are ${all.map((Dependency d) => d.path).join(', ')}',
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
}


Dependency _read(File manifest, Directory modules) {
  final dynamic document = loadYaml(manifest.readAsStringSync());
  if (document is! YamlMap) {
    throwToolExit('${manifest.path}: manifest is not a YAML mapping');
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
