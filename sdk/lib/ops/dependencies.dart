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

const String fragmentDirectory = 'ops';
const String overlayTemplate = 'overlay.yaml';
const String overlayBase = 'name: "{{app_name_snake}}"\nservices:\n';

/// The directory, inside a module, holding its SQL.
const String sqlDirectory = 'db';

/// The subdirectory of [sqlDirectory] played when the stack is built.
const String sqlInitDirectory = 'init';

/// What a directory has to carry to be a module.
///
/// These are the things the tools read from a module, and a directory that
/// carries none of them holds nothing a project could mount.
const Set<String> moduleArtefacts = <String>{
  fragmentDirectory,
  sqlDirectory,
  'protocol',
  'register.ts',
  'deno.json',
};

/// The one module a project gets whether or not it names it.
const String foundationPath = 'foundation';

String overlayFileName(String path) => 'overlay.${path.replaceAll('/', '-')}.yaml';

/// One mountable module, recognised by the artefacts its directory carries.
class Dependency {
  const Dependency({required this.path, required this.directory});

  /// The module's address, relative to the root that carries it.
  final String path;

  /// The directory the module lives in.
  final Directory directory;

  /// The SQL this module adds to the database, null when it ships none.
  Directory? get sql {
    final Directory found = Directory(p.join(directory.path, sqlDirectory, sqlInitDirectory));
    return found.existsSync() ? found : null;
  }

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

/// Every module found under the dependency roots.
class Dependencies {
  const Dependencies(this.all);

  /// Every module found, sorted by [Dependency.path].
  final List<Dependency> all;

  /// Every module under [roots], both host roots by default.
  ///
  /// There are two roots and not one because a module can live in either of two
  /// repositories: `host/dependencies/` holds what the framework owns, and
  /// `host/packages/` is the submodule where the mountable packages live. A
  /// module's address stays relative to the root that carries it.
  ///
  /// A root that does not exist yields nothing rather than failing, since a
  /// clone without `--recurse-submodules` has no `host/packages/` at all.
  static Dependencies load({List<Directory>? roots}) {
    final List<Directory> searched = roots ?? _defaultRoots();
    final List<Dependency> found = <Dependency>[];

    for (final Directory modules in searched) {
      if (!modules.existsSync()) continue;
      _collect(modules, modules, found);
    }

    found.sort((Dependency a, Dependency b) => a.path.compareTo(b.path));

    return Dependencies(found);
  }

  /// Adds the modules under [directory] to [found], addressed against [root].
  ///
  /// The walk never enters a module, since a module's own subdirectories carry
  /// the same names it does: `foundation/ops/database/` holds a compose
  /// fragment, and it is a subject of `foundation` rather than a module.
  static void _collect(Directory directory, Directory root, List<Dependency> found) {
    for (final Directory child in directory.listSync(followLinks: false).whereType<Directory>()) {
      if (_isModule(child)) {
        found.add(Dependency(path: p.relative(child.path, from: root.path), directory: child));
        continue;
      }

      _collect(child, root, found);
    }
  }

  /// Whether [directory] carries any of [moduleArtefacts].
  static bool _isModule(Directory directory) => moduleArtefacts.any(
    (String artefact) =>
        FileSystemEntity.typeSync(p.join(directory.path, artefact), followLinks: false) !=
        FileSystemEntityType.notFound,
  );

  static List<Directory> _defaultRoots() => <Directory>[
    InfraFiles.tree.scribe.host.dependencies.directory,
    InfraFiles.tree.scribe.host.packages.directory,
  ];

  /// The modules the current project mounts.
  List<Dependency> get active => selected(configuredSelection());

  /// The module at [path], or null when there is none.
  Dependency? byPath(String path) {
    for (final Dependency dependency in all) {
      if (dependency.path == path) return dependency;
    }
    return null;
  }

  /// The modules [wanted] asks for, plus the one at [foundationPath].
  ///
  /// A module is mounted because a project named it, and for no other reason.
  /// What a module needs from a neighbour it asks for at the endpoint that
  /// needs it, so mounting one never drags another one in.
  List<Dependency> selected(List<String> wanted) {
    for (final String path in wanted) {
      if (byPath(path) == null) {
        throw CliException(
          'config.yaml: unknown dependency "$path". The '
          'known ones are ${all.map((Dependency d) => d.path).join(', ')}.',
        );
      }
    }

    final Set<String> keep = <String>{foundationPath, ...wanted};
    return all.where((Dependency dependency) => keep.contains(dependency.path)).toList();
  }

  /// The slices of [template] declared by [active], in the order they are given.
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
