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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/deploy/configuration_audit.dart';
import 'package:scribe_tools/src/forge/declarations.dart';
import 'package:scribe_tools/src/forge/di_wiring.dart';
import 'package:scribe_tools/src/forge/registrations.dart';
import 'package:scribe_tools/src/forge/scribe_config.dart';
import 'package:scribe_tools/src/forge/sql/generate_package_sql.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/configuration.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';

/// Gives a project or a package everything it derives from what it declares.
///
/// It is the command to reach for when something is missing without having to
/// know what. In a project it owns `configuration/`: a file that is not there is
/// written with the defaults its module declares, one that is there is left
/// exactly as it is, and what is wrong inside it is named rather than corrected,
/// because correcting a file somebody filled in would destroy an intention
/// nobody understood. In a package it resolves what the manifest reaches against
/// the checkout and writes it down for the tools, which is the one place a
/// package and a checkout meet.
///
/// A project also gets everything `dependencies:` decides in the same step: the
/// lock, the import map, the registrations and the declarations found under
/// `lib/`. Resolving what a project mounts and writing what that mounting means
/// used to be two commands, this one and `scribe gen code`, and a project whose
/// `config.yaml` changed without a `gen code` that followed ran on a stale map.
/// `pub get` never splits that in two, so neither does this: see `generate.dart`
/// for what stayed a separate command, because nothing but the SQL decides it.
///
/// It also finds every class `lib/` marks `@Singleton` and writes the imports
/// that make each one register itself, whether or not the project mounts any
/// package: this one answers to nothing `dependencies:` names.
///
/// Which of the two it does is read from the directory it runs in: a
/// `config.yaml` makes it a project, a `package.yaml` makes it a package.
class ForgeCommand extends ScribeCommand {
  /// Declares the flag that looks without writing.
  ForgeCommand() {
    argParser
      ..addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: 'In a project, say what is missing and what is wrong and write nothing.',
      )
      ..addFlag(
        ScribeCommand.machineOption,
        negatable: false,
        help: 'Print one line of JSON instead of a report a person reads.',
      )
      ..addFlag(
        ScribeCommand.watchOption,
        negatable: false,
        help: 'ConfigurationAudit again every time lib/ or the manifest changes, instead of once.',
      );
  }

  @override
  String get name => 'forge';

  @override
  String get description => 'Give this project or package everything it declares and does not yet carry.';

  @override
  String get invocation => 'scribe forge [--dry-run] [--machine] [--watch]';

  /// It decides for itself whether it is in a project or a package.
  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Directory here = globals.fs.currentDirectory;
    final bool watch = boolArg(ScribeCommand.watchOption);

    if (Project.isProjectRoot(here)) {
      final ScribeCommandResult first = await _forgeProject();
      if (!watch) return first;

      return watchAndRerun(<FileSystemEntity>[project.lib, project.config], _forgeProject);
    }

    if (here.childFile(kManifestFile).existsSync()) {
      final ScribeCommandResult first = await _resolvePackage(here.path);
      if (!watch) return first;

      return watchAndRerun(<FileSystemEntity>[
        here.childDirectory(kLibraryDirectory),
        here.childFile(kManifestFile),
      ], () => _resolvePackage(here.path));
    }

    throwToolExit(
      'forge runs at the root of a scribe project or of a package, and ${here.path} is neither: '
      'it holds no ${Project.configFileName} and no $kManifestFile.',
    );
  }

  Future<ScribeCommandResult> _forgeProject() async {
    final bool dryRun = boolArg('dry-run');
    final bool machine = boolArg(ScribeCommand.machineOption);
    final ProjectForgeResult result = await forgeProject(project, write: !dryRun, quiet: machine);
    final AuditReport report = result.report;

    if (machine) {
      printMachine(
        forgeProjectMachineReport(
          report,
          dryRun: dryRun,
          lockFile: result.lockFile,
          scribeVersion: result.scribeVersion,
        ),
      );

      return report.hasProblems ? const ScribeCommandResult.fail() : const ScribeCommandResult.success();
    }

    for (final AuditEntry entry in report.entries) {
      globals.logger.printStatus(_lineOf(entry, dryRun: dryRun));
    }

    for (final String problem in report.problems) {
      globals.logger.printError(problem);
    }

    if (result.lockFile != null) {
      globals.logger.printStatus('');
      globals.logger.printStatus(
        '${result.lockFile} written, freezing what this project mounts at ${result.scribeVersion}.',
      );
    }

    globals.logger.printStatus('');
    globals.logger.printStatus(_summaryOf(report, dryRun: dryRun));

    return report.hasProblems ? const ScribeCommandResult.fail() : const ScribeCommandResult.success();
  }

  /// Resolves the package in [directory] against the checkout and writes it down.
  ///
  /// A package asking for what it needs is the same act as a project asking for
  /// what it declares, so one word covers both. What resolving contains and why
  /// is in `package/resolution.dart`.
  Future<ScribeCommandResult> _resolvePackage(String directory) async {
    if (boolArg('dry-run')) {
      throwUsageError(
        '--dry-run only means something in a project, where a file may be missing. '
        'A package is resolved or it is not.',
        command: invocationName,
      );
    }

    final Sdk sdk = findSdk(from: directory);
    final Resolution resolution = resolve(directory, sdk);
    final GeneratedSqlReport? sql = await generatePackageSql(directory, resolution);

    if (boolArg(ScribeCommand.machineOption)) {
      printMachine(forgePackageMachineReport(sdk, resolution, sql));

      return const ScribeCommandResult.success();
    }

    globals.logger.printStatus('Resolved against scribe ${sdk.version} in ${sdk.root}.');
    for (final MapEntry<String, String> held in resolution.imports.entries) {
      globals.logger.printStatus('  ${held.key} ${held.value}');
    }
    globals.logger.printStatus('');
    globals.logger.printStatus('Written to ${resolution.file}, which git ignores and nobody edits.');
    globals.logger.printStatus(
      'Nothing named "deno.json" is written for it: `scribe test` hands deno this map directly, as '
      'a --import-map it never has to read off a disk, and the editor reads ${resolution.file} on its own.',
    );
    globals.logger.printStatus(
      'The versions found are frozen in ${resolution.lockFile}, which is committed: '
      'run forge again after a dependency or the checkout changes, and it is rewritten to match.',
    );

    if (sql != null) {
      globals.logger.printStatus('');
      globals.logger.printStatus(
        '${sql.file} written from schema/: ${sql.enumCount} enum(s), ${sql.compositeTypeCount} composite '
        'type(s), ${sql.tableCount} table(s), ${sql.functionCount} function(s), ${sql.triggerCount} '
        'trigger(s), ${sql.cronJobCount} cron job(s).',
      );
    }

    return const ScribeCommandResult.success();
  }

  String _lineOf(AuditEntry entry, {required bool dryRun}) {
    final String path = '$configurationDirectoryName/${entry.name}.yaml';

    return switch (entry.verdict) {
      AuditVerdict.written => '  + $path${dryRun ? '   missing' : '   written, module defaults'}',
      AuditVerdict.kept => '  ~ $path   already there, left as it is',
      AuditVerdict.orphaned => '  ! $path   nothing depends on ${entry.name} any more',
    };
  }

  String _summaryOf(AuditReport report, {required bool dryRun}) {
    final int written = report.written.length;
    final int orphaned = report.orphaned.length;
    final int problems = report.problems.length;

    return <String>[
      '$written file(s) ${dryRun ? 'missing' : 'written'}',
      if (orphaned > 0) '$orphaned orphan(s)',
      if (problems > 0) '$problems problem(s)',
    ].join(', ');
  }
}

/// What forging a project produced.
class ProjectForgeResult {
  /// Records what [ConfigurationAudit] found, and what writing it left behind.
  const ProjectForgeResult({required this.report, required this.lockFile, required this.scribeVersion});

  /// What each file of `configuration/` came out as.
  final AuditReport report;

  /// The path `scribe.lock` was written to, null when nothing was written.
  final String? lockFile;

  /// The framework version the lock freezes against, null when nothing was written.
  final String? scribeVersion;
}

/// Forges [project]: writes `configuration/`, then, unless [write] is false,
/// the lock and everything `dependencies:` derives under `lib/`'s own alias.
///
/// A top-level function and not a method on `ForgeCommand`: `scribe daemon`
/// runs the same forge a request handler already has to, and reaches for this
/// instead of a second `ForgeCommand` run through a captured logger, which
/// would be a second place the two could drift.
///
/// [quiet] silences what each generator prints as it writes, behind a
/// [QuietLogger] wrapped around the logger already active. `--machine` and
/// `scribe daemon` both want the one line they build themselves, not a status
/// a person watching would have seen scroll by. The logger is read before the
/// child context opens: reading it inside the override that builds one trips
/// `AppContext`'s own recursion guard, since that override is what the
/// context would resolve `Logger` to.
///
/// Throws a [ToolExit] when [project] is missing an entry a project needs.
Future<ProjectForgeResult> forgeProject(Project project, {bool write = true, bool quiet = false}) async {
  final List<String> missing = project.missingEntries;
  if (missing.isNotEmpty) {
    throwToolExit(
      '${project.directory.path} holds a ${Project.configFileName} but is missing ${missing.join(', ')}.\n'
      'A project needs its three entries: ${Project.configFileName}, lib/ and the derived directory.',
    );
  }

  final Packages packages = Packages.load();
  final List<Package> mounted = packages.active;
  final AuditReport report = ConfigurationAudit(project: project, packages: mounted).run(write: write);

  String? lockPath;
  String? scribeVersion;

  if (write) {
    scribeVersion = findSdk(from: project.sdk.path).version;
    final File lockFile = globals.fs.file(p.join(project.directory.path, kProjectLockFile));
    packages.lockOf(mounted, scribeVersion).writeTo(lockFile);
    lockPath = lockFile.path;

    Future<void> writeGenerated() async {
      await generateScribeConfig(packages: packages);
      await generateRegistrations(packages: packages);
      await generateDeclarations(packages: packages);
      await generateDiWiring();
    }

    if (quiet) {
      final Logger outer = globals.logger;
      await globals.context.run<void>(
        name: 'forge quiet',
        overrides: <Type, Generator>{Logger: () => QuietLogger(outer)},
        body: writeGenerated,
      );
    } else {
      await writeGenerated();
    }
  }

  return ProjectForgeResult(report: report, lockFile: lockPath, scribeVersion: scribeVersion);
}

/// [report], in the shape `--machine` prints for a project.
///
/// A top-level function and not a method: `scribe daemon` builds the same
/// document from the same [AuditReport] a request handler already has, and
/// reaches for this instead of a second `ForgeCommand` run through a captured
/// logger.
Map<String, Object?> forgeProjectMachineReport(
  AuditReport report, {
  required bool dryRun,
  required String? lockFile,
  required String? scribeVersion,
}) => <String, Object?>{
  'command': 'forge',
  'kind': 'project',
  'ok': !report.hasProblems,
  'dryRun': dryRun,
  'entries': <Object?>[
    for (final AuditEntry entry in report.entries) <String, Object?>{'name': entry.name, 'verdict': entry.verdict.name},
  ],
  'problems': report.problems,
  'lockFile': lockFile,
  'scribeVersion': scribeVersion,
};

/// What [resolution] resolved [sdk] to, in the shape `--machine` prints for a package.
///
/// [sql] is null for a package that carries no `schema/`, and the report carries no `sql` key at
/// all then, rather than one holding nulls a reader would have to explain.
Map<String, Object?> forgePackageMachineReport(Sdk sdk, Resolution resolution, GeneratedSqlReport? sql) =>
    <String, Object?>{
      'command': 'forge',
      'kind': 'package',
      'ok': true,
      'sdk': <String, Object?>{'version': sdk.version, 'root': sdk.root},
      'imports': resolution.imports,
      'resolutionFile': resolution.file,
      'lockFile': resolution.lockFile,
      if (sql != null)
        'sql': <String, Object?>{
          'file': sql.file,
          'enums': sql.enumCount,
          'compositeTypes': sql.compositeTypeCount,
          'tables': sql.tableCount,
          'functions': sql.functionCount,
          'triggers': sql.triggerCount,
          'cronJobs': sql.cronJobCount,
        },
    };
