// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/deploy/settings.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:yaml/yaml.dart';

/// The directory a project holds how and where it runs in.
const String configurationDirectoryName = 'configuration';

/// The file holding the targets, the domains and the socle's placements.
const String mainConfigurationName = 'main';

/// The class a resource takes when a target places it nowhere else.
const String containerPlacement = 'container';

/// The class of a resource that exists already, whose outputs sit in the `.env`.
const String externalPlacement = 'external';

/// Where one resource is put on one target, and by which recipe.
class Placement {
  /// Holds a placement as a target declared it.
  const Placement({required this.className, this.recipe, this.params = const <String, Object?>{}});

  /// A container of the stack, which is what a target that says nothing gets.
  static const Placement inContainer = Placement(className: containerPlacement);

  /// Whether this resource is provisioned, or already there, or a container.
  ///
  /// `container` and `external` are classes of their own. Anything else is a
  /// recipe name, and the class is what the recipe does.
  final String className;

  /// The recipe answering for it, null for a container and for an external one.
  final String? recipe;

  /// What the recipe is given, a region, a size, whatever it declares it takes.
  final Map<String, Object?> params;

  /// Whether nothing has to be provisioned for it.
  bool get isContainer => className == containerPlacement;

  /// Whether it exists already and its outputs are read rather than created.
  bool get isExternal => className == externalPlacement;

  /// The recipe file name this placement resolves to, which is its class.
  String get recipeName => recipe ?? className;
}

/// One place a project can be deployed to, as `configuration/main.yaml` says.
class Target {
  /// Holds one target with everything that belongs to it and not to the project.
  const Target({
    required this.name,
    required this.kind,
    this.host = '',
    this.domain = '',
    this.dashboard = '',
    this.cors = const <String>[],
    this.machine,
    this.cpuCap = false,
    this.registry = '',
    this.tag = 'latest',
  });

  /// The name `--target` refers to it by.
  final String name;

  /// What it deploys onto, which decides how the stack is reached.
  final TargetKind kind;

  /// The `user@host` a remote driver reaches it at, empty when it is local.
  final String host;

  /// The domain this deployment answers on, which the proxy is rendered from.
  ///
  /// It belongs to the target and not to the project because a domain is the
  /// thing that differs between a workstation and a production deployment, and
  /// a project holding one value could never have two.
  final String domain;

  /// The domain the dashboard is served on, empty when this one serves none.
  final String dashboard;

  /// The origins a browser may call a node from on this target.
  final List<String> cors;

  /// The machine to size for, null when it is read where the stack will run.
  final Hardware? machine;

  /// Whether a service is capped at its share of the cores rather than weighted.
  final bool cpuCap;

  /// The registry the images of this deployment are pushed to and pulled from.
  ///
  /// Naming one is what turns the images from something this machine builds and
  /// mounts into something a host somewhere else can pull: a host that is not
  /// this one cannot see `./lib`, so the project has to be inside the image.
  final String registry;

  /// The tag the images of this deployment carry.
  final String tag;
}

/// How and where a project runs, read from its `configuration/` directory.
///
/// One reader for the whole engine: whether a value comes from `configuration/`
/// or, while the directory is being introduced, from the manifest that used to
/// hold it, is this class's business and nobody else's.
class ProjectConfiguration {
  /// Holds what was read, for [project].
  const ProjectConfiguration({required this.project, required this.targets, required this.modules});

  /// The project this describes.
  final Project project;

  /// Every target the project declares, in the order it declared them.
  final List<Target> targets;

  /// What each module's file holds, by module name, settings and placements.
  final Map<String, YamlMap> modules;

  /// The directory the files sit in, whether or not it exists yet.
  static Directory directoryOf(Project project) => project.directory.childDirectory(configurationDirectoryName);

  /// Reads [project], falling back to the manifest for what has not moved yet.
  ///
  /// `configuration/main.yaml` is the place targets belong, and `config.yaml`
  /// held them before it existed. Reading both here rather than in the engine is
  /// what keeps the fallback from becoming a second source of truth: `forge`
  /// writes the file, and the fallback stops being reached.
  static ProjectConfiguration load({Project? project}) {
    final Project found = project ?? globals.project;
    final Directory root = directoryOf(found);

    return ProjectConfiguration(
      project: found,
      targets: _targetsOf(found, root),
      modules: <String, YamlMap>{
        if (root.existsSync())
          for (final File file in root.listSync().whereType<File>().toList()..sort(_byPath))
            if (p.basenameWithoutExtension(file.path) != mainConfigurationName && p.extension(file.path) == '.yaml')
              p.basenameWithoutExtension(file.path): _mapping(file),
      },
    );
  }

  /// The target named [name], refused by listing the ones that exist.
  Target target(String name) => targets.firstWhere(
    (Target target) => target.name == name,
    orElse: () => throwToolExit(
      'No target named "$name".\n'
      '${targets.isEmpty ? 'This project declares none: add one to configuration/main.yaml.' : 'It declares ${targets.map((Target t) => t.name).join(', ')}.'}',
    ),
  );

  /// Where [resource] goes on [target], a container when nothing says otherwise.
  ///
  /// The socle's placements sit in `main.yaml` and a package's in its own file,
  /// because the placement of a bucket is a matter for `storage` rather than a
  /// matter for the target. Both are searched, and the module's own file wins.
  Placement placementOf(String target, String resource) {
    for (final YamlMap module in modules.values) {
      final Placement? found = _placementIn(module, target, resource);
      if (found != null) return found;
    }

    final File main = directoryOf(project).childFile('$mainConfigurationName.yaml');

    return (main.existsSync() ? _placementIn(_mapping(main), target, resource) : null) ?? Placement.inContainer;
  }

  /// What [module] was configured with, empty when it has no file.
  Map<String, Object?> settingsOf(String module) {
    final YamlMap? found = modules[module];
    if (found == null) return const <String, Object?>{};

    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in found.entries)
        if ('${entry.key}' != deployKey) '${entry.key}': entry.value,
    };
  }

  static Placement? _placementIn(YamlMap document, String target, String resource) {
    final Object? deploy = document[deployKey];
    if (deploy is! YamlMap) return null;

    final Object? forTarget = deploy[target];
    if (forTarget is! YamlMap) return null;

    final Object? placement = forTarget[resource];
    if (placement == null) return null;
    if (placement is String) return Placement(className: placement);
    if (placement is! YamlMap) return null;

    final Object? recipe = placement['recipe'];

    return Placement(
      className: recipe is String ? recipe : '${placement['class'] ?? containerPlacement}',
      recipe: recipe is String ? recipe : null,
      params: <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in placement.entries)
          if ('${entry.key}' != 'recipe' && '${entry.key}' != 'class') '${entry.key}': entry.value,
      },
    );
  }

  static List<Target> _targetsOf(Project project, Directory root) {
    final File main = root.childFile('$mainConfigurationName.yaml');
    if (!main.existsSync()) return _targetsFromManifest(project);

    final Object? declared = _mapping(main)['targets'];
    if (declared is! YamlMap) return const <Target>[];

    return <Target>[
      for (final MapEntry<Object?, Object?> entry in declared.entries) _readTarget('${entry.key}', entry.value, main),
    ];
  }

  /// The targets the manifest holds, for a project `forge` has not written yet.
  static List<Target> _targetsFromManifest(Project project) {
    final ScribeManifest manifest = project.manifest;

    return <Target>[
      for (final String name in manifest.targetNames)
        Target(
          name: name,
          kind: manifest.kindOf(name),
          domain: manifest.apiUrl,
          machine: manifest.machineOf(name),
          cpuCap: manifest.cpuCapOf(name),
        ),
    ];
  }

  static Target _readTarget(String name, Object? entry, File file) {
    if (entry is! YamlMap) {
      throwToolExit('${file.path}: target "$name" must be a mapping.');
    }

    final Object? kind = entry['kind'];
    if (kind != null && kind is! String) {
      throwToolExit('${file.path}: targets.$name.kind must be text.');
    }

    final Object? machine = entry['machine'];

    return Target(
      name: name,
      kind: _kind(kind as String?, name, file),
      host: '${entry['host'] ?? ''}',
      domain: '${entry['domain'] ?? ''}',
      dashboard: '${entry['dashboard'] ?? ''}',
      cors: <String>[
        if (entry['cors'] case final YamlList origins)
          for (final Object? origin in origins) '$origin',
      ],
      machine: _machine(machine, name, file),
      cpuCap: entry['cpu_cap'] == true,
      registry: '${entry['registry'] ?? ''}',
      tag: '${entry['tag'] ?? 'latest'}',
    );
  }

  /// The machine [declared] names, null when it is read where the stack runs.
  ///
  /// `host` stays a scalar because it is the one value that is not a description
  /// but an instruction, read the machine this is running on.
  static Hardware? _machine(Object? declared, String name, File file) {
    if (declared == null || declared == 'host') return null;
    if (declared is! Map<Object?, Object?>) {
      throwToolExit(
        '${file.path}: targets.$name.machine holds "$declared", which does not name a machine.\n'
        'Write it key by key, cores, threads and memory, or "host" to read this one.',
      );
    }

    return Hardware.parse(declared, field: 'targets.$name.machine');
  }

  static TargetKind _kind(String? written, String name, File file) {
    if (written == null) return TargetKind.machine;

    return TargetKind.values.firstWhere(
      (TargetKind kind) => kind.name == written,
      orElse: () => throwToolExit(
        '${file.path}: targets.$name.kind holds "$written", which is not a kind of target.\n'
        'Write one of: ${TargetKind.values.map((TargetKind kind) => kind.name).join(', ')}.',
      ),
    );
  }

  static YamlMap _mapping(File file) {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throwToolExit('${file.path}: the file must be a mapping.');
    }

    return document;
  }

  static int _byPath(File a, File b) => a.path.compareTo(b.path);
}
