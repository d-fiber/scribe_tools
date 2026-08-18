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
import 'package:scribe/src/ops/fragments.dart';

/// The file whose presence makes a directory a mountable module.
const String manifestName = 'scribe.yaml';

/// The directory, inside a module, holding its slices of the ops templates.
const String fragmentDirectory = 'ops';

/// What a module asks of the stack around it, from the `ops` block of its manifest.
class DependencyInfra {
  const DependencyInfra({
    required this.services,
    required this.profile,
    required this.gateway,
    required this.env,
  });

  /// The compose services this module needs running.
  final List<String> services;

  /// The compose profile its services are started under, null when they always are.
  final String? profile;

  /// The gateway fragments its routes need in front of them.
  final List<String> gateway;

  /// The environment variables it reads.
  final List<String> env;
}

/// One mountable module, read from its `scribe.yaml`.
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

  /// The module's address, relative to the dependencies root: `security/auth`.
  ///
  /// This is what `config.yaml` names a module by, and what [requires] points at.
  final String path;

  /// The module's identifier, its directory name when the manifest declares none.
  final String name;

  /// The one line describing it to a human.
  final String title;

  /// Whether a project has to ask for this module to get it.
  ///
  /// True unless the manifest says otherwise, so a module has to declare itself
  /// mandatory to be mounted without being named.
  final bool optional;

  /// The modules this one is useless without, by [path].
  final List<String> requires;

  /// What it asks of the stack around it.
  final DependencyInfra infra;

  /// Its SQL directory, relative to [directory], null when it has none.
  final String? sql;

  /// Its `.proto` directory, relative to [directory], null when it has none.
  final String? protocol;

  /// The file the host imports it through, null when it exports nothing.
  final String? export;

  /// The route directories it mounts.
  final List<String> routes;

  /// The directory holding the manifest.
  final Directory directory;

  /// The files this module's slices of [template] would be read from.
  ///
  /// A package groups its ops by subject, so `ops/valkery/docker-compose.yaml`
  /// counts as much as `ops/docker-compose.yaml`. None of them is required to
  /// exist: a module contributes to the templates it has something to say
  /// about and to no others.
  List<File> fragments(String template) {
    final Directory ops = directory.childDirectory(fragmentDirectory);
    if (!ops.existsSync()) return const <File>[];

    final List<File> found = <File>[ops.childFile(template)];
    for (final Directory subject in ops.listSync().whereType<Directory>()) {
      found.add(subject.childFile(template));
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

/// Every module found under the dependency roots.
class Dependencies {
  const Dependencies(this.all);

  /// Every module found, sorted by [Dependency.path].
  final List<Dependency> all;

  /// Every module under [roots], the project's vendored framework by default.
  ///
  /// There are two roots and not one because a module can live in either of two
  /// repositories: `host/dependencies/` holds what the framework owns, and
  /// `host/packages/` is the submodule where the mountable packages live. A
  /// module's address stays relative to the root that carries it, so moving one
  /// between the two leaves `security/auth` spelled `security/auth` — which is
  /// what a project wrote in its `config.yaml`, and what must not break.
  ///
  /// The search is recursive and keyed on [manifestName], so a family holds as
  /// many levels as it needs. A root that does not exist yields nothing rather
  /// than failing: a project can be read before its framework is vendored in,
  /// and a clone without `--recurse-submodules` has no `host/packages/` at all.
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
    globals.fs.directory(globals.project.sdk.hostDependencies.path),
    globals.fs.directory(globals.project.sdk.hostPackages.path),
  ];

  /// The modules the current project mounts.
  List<Dependency> get active => selected(globals.project.manifest.dependencies);

  /// The Compose profiles [mounted] asks for, sorted, without repetition.
  ///
  /// A module declares its profile in the `ops` block of its manifest, and
  /// several share one: `security/vpn` and `features/observability` are both
  /// under `ops`, so either of them switches the whole profile on, `studio`
  /// included. A module that declares none has services that always start.
  static List<String> profilesOf(Iterable<Dependency> mounted) => <String>{
    for (final Dependency dependency in mounted)
      if (dependency.infra.profile case final String profile) profile,
  }.toList()..sort();

  /// The module at [path], or null when there is none.
  Dependency? byPath(String path) {
    for (final Dependency dependency in all) {
      if (dependency.path == path) return dependency;
    }
    return null;
  }

  /// The modules [wanted] asks for, the mandatory ones, and everything they require.
  ///
  /// [Dependency.requires] is followed until nothing more is added, so naming a
  /// module is enough to get what it needs underneath. An empty [wanted] means
  /// a project that declared no list, and takes everything.
  ///
  /// Throws a [ToolExit] naming the known modules when [wanted] holds a path
  /// that is not one.
  List<Dependency> selected(List<String> wanted) {
    if (wanted.isEmpty) return all;

    final Set<String> keep = <String>{
      for (final Dependency dependency in all)
        if (!dependency.optional) dependency.path,
    };

    for (final String path in wanted) {
      if (byPath(path) == null) {
        throwToolExit(
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

  /// The slices of [template] declared by [active], in the order they are given.
  ///
  /// A module that declares none is skipped rather than contributing an empty
  /// block, so the merged document only names the modules that had something
  /// to add to it.
  List<YamlFragment> fragmentsFor(String template, List<Dependency> active) => <YamlFragment>[
    for (final Dependency dependency in active) ...dependency.fragmentsFor(template),
  ];
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
