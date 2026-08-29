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
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/deploy/settings.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// What one file of `configuration/` came out of a forge as.
enum ForgeVerdict {
  /// It was not there, and was written with the defaults its module declares.
  written,

  /// It was there, and was left exactly as it is.
  kept,

  /// It is there and its module is no longer a dependency.
  orphaned,
}

/// One file, and what the forge did or refused to do about it.
class ForgeEntry {
  /// Holds one file's outcome.
  const ForgeEntry({required this.name, required this.verdict, this.problems = const <String>[]});

  /// The file's name under `configuration/`, without its extension.
  final String name;

  /// What happened to it.
  final ForgeVerdict verdict;

  /// What is wrong inside it, said one line per problem.
  ///
  /// A file the developer wrote is never corrected, because correcting it would
  /// destroy an intention nobody understood. Saying precisely what is wrong is
  /// the other half of "the project is always right", and it is the half a tool
  /// may do.
  final List<String> problems;
}

/// What a whole forge came out as.
class ForgeReport {
  /// Holds every file the forge looked at.
  const ForgeReport(this.entries);

  /// One entry per file, in the order the modules were read.
  final List<ForgeEntry> entries;

  /// The files that were written, which is what a project gained.
  Iterable<ForgeEntry> get written => entries.where((ForgeEntry e) => e.verdict == ForgeVerdict.written);

  /// The files whose module is no longer a dependency.
  Iterable<ForgeEntry> get orphaned => entries.where((ForgeEntry e) => e.verdict == ForgeVerdict.orphaned);

  /// Every problem found, prefixed by the file it sits in.
  List<String> get problems => <String>[
    for (final ForgeEntry entry in entries)
      for (final String problem in entry.problems) '$configurationDirectoryName/${entry.name}.yaml: $problem',
  ];

  /// Whether anything is wrong, which is what makes a command refuse.
  bool get hasProblems => entries.any((ForgeEntry entry) => entry.problems.isNotEmpty);
}

/// Brings a project back in line with what it declares.
///
/// It owns what nobody edits and audits what the developer edits. A file of
/// `configuration/` that is not there is written with the defaults its module
/// declares; one that is there is left alone, whatever it holds, and what is
/// wrong inside it is named rather than corrected.
class Forge {
  /// Forges [project] against [packages], the selection it declares.
  Forge({required this.project, required this.packages});

  /// The project being brought back in line.
  final Project project;

  /// The packages the project mounts, whose declarations decide what is written.
  final List<Package> packages;

  /// Looks at every file, writing the missing ones unless [write] is false.
  ForgeReport run({bool write = true}) {
    final Directory root = ProjectConfiguration.directoryOf(project);
    final List<ForgeEntry> entries = <ForgeEntry>[_main(root, write: write)];
    final Set<String> known = <String>{mainConfigurationName};

    for (final Package package in packages) {
      final File declaration = package.directory.childFile(configurationFileName);
      final Settings declared = Settings.read(declaration);
      final List<String> resources = <String>[
        for (final Resource resource in Resources.declaredIn(declaration)) resource.name,
      ];

      // A package with no setting can still need a resource, and a project has
      // to be given somewhere to place it. What decides is the two together.
      if (declared.isEmpty && resources.isEmpty) continue;

      known.add(package.name);
      entries.add(_module(root, package, declared, resources, write: write));
    }

    for (final String name in _filesIn(root)) {
      if (!known.contains(name)) entries.add(ForgeEntry(name: name, verdict: ForgeVerdict.orphaned));
    }

    return ForgeReport(entries);
  }

  /// The targets a written `main.yaml` starts from, taken from the manifest.
  ///
  /// A project that predates `configuration/` holds them in `config.yaml`, and
  /// this is the one moment they move. A project that has neither gets a `local`
  /// target, because a file naming no target at all can only be refused later.
  String scaffoldMain() {
    final List<Target> targets = ProjectConfiguration.load(project: project).targets;
    final StringBuffer out = StringBuffer()
      ..writeln('# configuration/$mainConfigurationName.yaml')
      ..writeln('#')
      ..writeln('# Written by `scribe forge`. This file holds where this project runs, one')
      ..writeln('# block per target, and where the resources of the socle are placed.')
      ..writeln()
      ..writeln('targets:');

    for (final Target target in targets.isEmpty ? _defaultTargets : targets) {
      out
        ..writeln('  ${target.name}:')
        ..writeln('    kind: ${target.kind.name}');
      if (target.host.isNotEmpty) out.writeln('    host: "${target.host}"');
      if (target.domain.isNotEmpty) out.writeln('    domain: "${target.domain}"');
      if (target.dashboard.isNotEmpty) out.writeln('    dashboard: "${target.dashboard}"');
      if (target.machine case final Hardware machine) {
        out
          ..writeln('    machine:')
          ..writeln('      cores: ${machine.cores}')
          ..writeln('      threads: ${machine.threads}')
          ..writeln('      memory: ${machine.memoryGb}g');
      }
      if (target.cpuCap) out.writeln('    cpu_cap: true');
      out.writeln();
    }

    final List<String> resources = <String>[
      for (final Resource resource in Resources.declaredIn(_socleDeclaration())) resource.name,
    ];

    return (out
          ..writeln('# Where each resource of the socle is placed, per target. A target that is')
          ..writeln('# not named here gets a container alongside the rest of the stack.')
          ..writeln('#')
          ..writeln(
            resources.isEmpty
                ? '# The socle needs none, so this block stays empty.'
                : '# The socle needs these, always, on every project: ${resources.join(', ')}.',
          )
          ..writeln('$deployKey: {}'))
        .toString();
  }

  /// The file the socle declares its own resources in, the way a package does.
  static File _socleDeclaration() => SocleOps().root.childFile('$configurationFileName$kTemplateSuffix');

  static const List<Target> _defaultTargets = <Target>[Target(name: 'local', kind: TargetKind.dev)];

  ForgeEntry _main(Directory root, {required bool write}) {
    final File file = root.childFile('$mainConfigurationName.yaml');
    if (!file.existsSync()) {
      // The content is built before the file exists on purpose: it is read from
      // the manifest through the same reader that would find this file, and an
      // empty file created first is a file that reader refuses.
      final String content = scaffoldMain();
      if (write) {
        file
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      }

      return const ForgeEntry(name: mainConfigurationName, verdict: ForgeVerdict.written);
    }

    return const ForgeEntry(name: mainConfigurationName, verdict: ForgeVerdict.kept);
  }

  ForgeEntry _module(
    Directory root,
    Package package,
    Settings declared,
    List<String> resources, {
    required bool write,
  }) {
    final File file = root.childFile('${package.name}.yaml');
    if (!file.existsSync()) {
      final String content = declared.scaffold(
        module: package.name,
        version: _versionOf(package),
        resources: resources,
      );
      if (write) {
        file
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      }

      return ForgeEntry(name: package.name, verdict: ForgeVerdict.written);
    }

    return ForgeEntry(name: package.name, verdict: ForgeVerdict.kept, problems: _audit(file, declared));
  }

  /// The version [package] declares, empty when its manifest does not say.
  ///
  /// It goes in the header of a scaffolded file so that a setting appearing in a
  /// later version can be traced to the version the file was written from.
  static String _versionOf(Package package) {
    final File manifest = package.directory.childFile('package.yaml');
    if (!manifest.existsSync()) return '';

    final Object? document = loadYaml(manifest.readAsStringSync());

    return document is YamlMap && document['version'] is String ? document['version'] as String : '';
  }

  /// Everything wrong inside [file], measured against what [declared] says.
  ///
  /// Four things are looked for, and the last of them is not an error: a key the
  /// module does not declare, a value of the wrong shape, a target nothing
  /// declares, and a setting a newer version of the module added.
  List<String> _audit(File file, Settings declared) {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return <String>['the file must be a mapping.'];

    final Map<String, Setting> known = <String, Setting>{
      for (final Setting setting in declared.settings) setting.name: setting,
    };
    final Set<String> targets = <String>{
      for (final Target target in ProjectConfiguration.load(project: project).targets) target.name,
    };
    final List<String> problems = <String>[];

    for (final MapEntry<Object?, Object?> entry in document.entries) {
      final String key = '${entry.key}';
      if (key == deployKey) {
        problems.addAll(_deployProblems(entry.value, targets));
        continue;
      }

      final Setting? setting = known[key];
      if (setting == null) {
        problems.add('"$key" is not a setting. This module declares: ${known.keys.join(', ')}');
        continue;
      }

      if (!_matches(entry.value, setting.type)) {
        problems.add('"$key" is a ${setting.type}, and holds ${_shapeOf(entry.value)}');
      }
    }

    for (final Setting setting in declared.settings) {
      if (!document.containsKey(setting.name)) {
        problems.add(
          '"${setting.name}" was added by a newer version of this module, and defaults to '
          '${setting.defaultValue}. It is not written in for you.',
        );
      }
    }

    return problems;
  }

  List<String> _deployProblems(Object? deploy, Set<String> targets) {
    if (deploy is! YamlMap) return const <String>[];

    return <String>[
      for (final Object? name in deploy.keys)
        if (!targets.contains('$name')) _noSuchTarget('$name', targets),
    ];
  }

  static String _noSuchTarget(String name, Set<String> targets) =>
      '$deployKey.$name: no target is called that. '
      'This project declares: ${targets.isEmpty ? 'none' : targets.join(', ')}';

  static bool _matches(Object? value, String type) => switch (type) {
    'string' => value is String,
    'integer' => value is int,
    'boolean' => value is bool,
    'list' => value is List,
    'map' => value is Map,
    _ => true,
  };

  static String _shapeOf(Object? value) => switch (value) {
    null => 'nothing',
    final String _ => 'text',
    final int _ => 'a number',
    final bool _ => 'a boolean',
    final List<Object?> _ => 'a list',
    final Map<Object?, Object?> _ => 'a mapping',
    _ => 'something else',
  };

  static int _byPath(File a, File b) => a.path.compareTo(b.path);

  static List<String> _filesIn(Directory root) {
    if (!root.existsSync()) return const <String>[];

    return <String>[
      for (final File file in root.listSync().whereType<File>().toList()..sort(_byPath))
        if (p.extension(file.path) == '.yaml') p.basenameWithoutExtension(file.path),
    ];
  }
}
