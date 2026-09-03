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
import 'package:scribe_tools/src/ops/configuration.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/resources.dart';
import 'package:scribe_tools/src/ops/settings.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// What one file of `configuration/` came out of a forge as.
enum AuditVerdict {
  /// It was not there, and was written with the defaults its module declares.
  written,

  /// It was there, and was left exactly as it is.
  kept,

  /// It is there and its module is no longer a dependency.
  orphaned,
}

/// One file, and what the forge did or refused to do about it.
class AuditEntry {
  /// Holds one file's outcome.
  const AuditEntry({
    required this.name,
    required this.verdict,
    this.problems = const <String>[],
    this.notices = const <String>[],
  });

  /// The file's name under `configuration/`, without its extension.
  final String name;

  /// What happened to it.
  final AuditVerdict verdict;

  /// What is wrong inside it, said one line per problem.
  ///
  /// A file the developer wrote is never corrected, because correcting it would
  /// destroy an intention nobody understood. Saying precisely what is wrong is
  /// the other half of "the project is always right", and it is the half a tool
  /// may do.
  final List<String> problems;

  /// What is worth telling about it without refusing anything, one line each.
  ///
  /// A setting a newer version of the module added and this file does not carry yet lives here,
  /// never in [problems]: `run`, `deploy` and `forge --machine` all refuse a project whose report
  /// [AuditReport.hasProblems], and nothing here is something the developer did wrong.
  final List<String> notices;
}

/// What a whole forge came out as.
class AuditReport {
  /// Holds every file the forge looked at.
  const AuditReport(this.entries);

  /// One entry per file, in the order the modules were read.
  final List<AuditEntry> entries;

  /// The files that were written, which is what a project gained.
  Iterable<AuditEntry> get written => entries.where((AuditEntry e) => e.verdict == AuditVerdict.written);

  /// The files whose module is no longer a dependency.
  Iterable<AuditEntry> get orphaned => entries.where((AuditEntry e) => e.verdict == AuditVerdict.orphaned);

  /// Every problem found, prefixed by the file it sits in.
  List<String> get problems => <String>[
    for (final AuditEntry entry in entries)
      for (final String problem in entry.problems) '$configurationDirectoryName/${entry.name}.yaml: $problem',
  ];

  /// Every notice found, prefixed by the file it sits in.
  List<String> get notices => <String>[
    for (final AuditEntry entry in entries)
      for (final String notice in entry.notices) '$configurationDirectoryName/${entry.name}.yaml: $notice',
  ];

  /// Whether anything is wrong, which is what makes a command refuse.
  bool get hasProblems => entries.any((AuditEntry entry) => entry.problems.isNotEmpty);
}

/// What [ConfigurationAudit._audit] found inside one file, split by whether it blocks a forge.
class _Audit {
  /// Holds [problems] and [notices] found in one file.
  const _Audit({required this.problems, required this.notices});

  /// What is wrong, and makes [AuditReport.hasProblems] true.
  final List<String> problems;

  /// What is worth telling without being wrong.
  final List<String> notices;
}

/// Brings a project back in line with what it declares.
///
/// It owns what nobody edits and audits what the developer edits. A file of
/// `configuration/` that is not there is written with the defaults its module
/// declares; one that is there is left alone, whatever it holds, and what is
/// wrong inside it is named rather than corrected.
class ConfigurationAudit {
  /// Audits [project] against [packages], the selection it declares.
  ConfigurationAudit({required this.project, required this.packages});

  /// The project being brought back in line.
  final Project project;

  /// The packages the project mounts, whose declarations decide what is written.
  final List<Package> packages;

  /// Looks at every file, writing the missing ones unless [write] is false.
  AuditReport run({bool write = true}) {
    final Directory root = ProjectConfiguration.directoryOf(project);
    final List<AuditEntry> entries = <AuditEntry>[_main(root, write: write)];
    final Set<String> known = <String>{mainConfigurationName};

    for (final Package package in packages) {
      final File declaration = package.directory.childDirectory(deployDirectory).childFile(configurationFileName);
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
      if (!known.contains(name)) entries.add(AuditEntry(name: name, verdict: AuditVerdict.orphaned));
    }

    return AuditReport(entries);
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

  AuditEntry _main(Directory root, {required bool write}) {
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

      return const AuditEntry(name: mainConfigurationName, verdict: AuditVerdict.written);
    }

    return AuditEntry(name: mainConfigurationName, verdict: AuditVerdict.kept, problems: _auditMain(file));
  }

  /// Everything wrong inside [file], which holds `targets:` and the socle's own `deploy:`.
  ///
  /// `main.yaml` has no `settings:` a module declares, so it is not run through
  /// [_audit]: only its targets and the names it places under `deploy:` can be
  /// wrong, never a setting's shape.
  List<String> _auditMain(File file) {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return <String>['the file must be a mapping.'];

    final Set<String> targets = <String>{
      for (final Target target in ProjectConfiguration.load(project: project).targets) target.name,
    };
    final Set<String> resources = <String>{
      for (final Resource resource in Resources.declaredIn(_socleDeclaration())) resource.name,
    };

    return _deployProblems(document[deployKey], targets, resources);
  }

  AuditEntry _module(
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

      return AuditEntry(name: package.name, verdict: AuditVerdict.written);
    }

    final _Audit audit = _audit(file, declared, resources.toSet());
    return AuditEntry(name: package.name, verdict: AuditVerdict.kept, problems: audit.problems, notices: audit.notices);
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

  /// Everything wrong inside [file], measured against what [declared] and
  /// [resources] say, plus what is worth telling without being wrong.
  ///
  /// Five things are looked for, and the last of them is a notice rather than a problem: a key
  /// the module does not declare, a value of the wrong shape, a target nothing declares, a
  /// resource name nothing declares, all four problems, and a setting a newer version of the
  /// module added, a notice.
  _Audit _audit(File file, Settings declared, Set<String> resources) {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return const _Audit(problems: <String>['the file must be a mapping.'], notices: <String>[]);

    final Map<String, Setting> known = <String, Setting>{
      for (final Setting setting in declared.settings) setting.name: setting,
    };
    final Set<String> targets = <String>{
      for (final Target target in ProjectConfiguration.load(project: project).targets) target.name,
    };
    final List<String> problems = <String>[];
    final List<String> notices = <String>[];

    for (final MapEntry<Object?, Object?> entry in document.entries) {
      final String key = '${entry.key}';
      if (key == deployKey) {
        problems.addAll(_deployProblems(entry.value, targets, resources));
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
        notices.add(
          '"${setting.name}" was added by a newer version of this module, and defaults to '
          '${setting.defaultValue}. It is not written in for you.',
        );
      }
    }

    return _Audit(problems: problems, notices: notices);
  }

  List<String> _deployProblems(Object? deploy, Set<String> targets, Set<String> resources) {
    if (deploy is! YamlMap) return const <String>[];

    final List<String> problems = <String>[];
    for (final MapEntry<Object?, Object?> target in deploy.entries) {
      final String name = '${target.key}';
      if (!targets.contains(name)) {
        problems.add(_noSuchTarget(name, targets));
        continue;
      }

      problems.addAll(_resourceProblems(name, target.value, resources));
    }

    return problems;
  }

  static String _noSuchTarget(String name, Set<String> targets) =>
      '$deployKey.$name: no target is called that. '
      'This project declares: ${targets.isEmpty ? 'none' : targets.join(', ')}';

  static List<String> _resourceProblems(String target, Object? placements, Set<String> resources) {
    if (placements is! YamlMap) return const <String>[];

    return <String>[
      for (final Object? name in placements.keys)
        if (!resources.contains('$name')) _noSuchResource('$name', target, resources),
    ];
  }

  static String _noSuchResource(String name, String target, Set<String> resources) =>
      '$deployKey.$target.$name: no resource is called that. '
      'This module declares: ${resources.isEmpty ? 'none' : resources.join(', ')}';

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

/// The refusal [project] gets for `run` or `deploy` when it has not been forged, null when it has.
///
/// `configuration/` is only half of what a forge writes: `scribe.json` and
/// `scribe.container.json` are the other half, and `generateProjectCode` does
/// not write them, only `forgeProject` does. A project whose `configuration/`
/// is complete can still be missing both, which is exactly what a fixture
/// copied straight from disk and never forged looks like: the stack renders,
/// `api` starts, and it dies three layers from the cause on a config file
/// that was never there.
String? refusalForAnUnforgedProject(Project project) {
  final AuditReport report = ConfigurationAudit(project: project, packages: Packages.load().active).run(write: false);
  final List<String> missingGenerated = <String>[
    if (!project.generated.sdk.importMap.existsSync()) project.generated.sdk.importMap.path,
    if (!project.generated.sdk.containerImportMap.existsSync()) project.generated.sdk.containerImportMap.path,
  ];

  if (report.written.isEmpty && !report.hasProblems && missingGenerated.isEmpty) return null;

  return <String>[
    if (report.written.isNotEmpty)
      'These files are missing: ${report.written.map((AuditEntry e) => '$configurationDirectoryName/${e.name}.yaml').join(', ')}',
    if (missingGenerated.isNotEmpty) 'These files are missing: ${missingGenerated.join(', ')}',
    ...report.problems,
    '',
    'scribe forge    writes what is missing and says what is wrong',
  ].join('\n');
}
