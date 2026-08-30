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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/forge.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

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
/// Which of the two it does is read from the directory it runs in: a
/// `config.yaml` makes it a project, a `package.yaml` makes it a package.
class ForgeCommand extends ScribeCommand {
  /// Declares the flag that looks without writing.
  ForgeCommand() {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'In a project, say what is missing and what is wrong and write nothing.',
    );
  }

  @override
  String get name => 'forge';

  @override
  String get description => 'Give this project or package everything it declares and does not yet carry.';

  @override
  String get invocation => 'scribe forge [--dry-run]';

  /// It decides for itself whether it is in a project or a package.
  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Directory here = globals.fs.currentDirectory;

    if (Project.isProjectRoot(here)) return _forgeProject();
    if (here.childFile(kManifestFile).existsSync()) return _resolvePackage(here.path);

    throwToolExit(
      'forge runs at the root of a scribe project or of a package, and ${here.path} is neither: '
      'it holds no ${Project.configFileName} and no $kManifestFile.',
    );
  }

  Future<ScribeCommandResult> _forgeProject() async {
    final List<String> missing = project.missingEntries;
    if (missing.isNotEmpty) {
      throwToolExit(
        '${project.directory.path} holds a ${Project.configFileName} but is missing ${missing.join(', ')}.\n'
        'A project needs its three entries: ${Project.configFileName}, lib/ and the derived directory.',
      );
    }

    final bool dryRun = boolArg('dry-run');
    final ForgeReport report = Forge(project: project, packages: Packages.load().active).run(write: !dryRun);

    for (final ForgeEntry entry in report.entries) {
      globals.logger.printStatus(_lineOf(entry, dryRun: dryRun));
    }

    for (final String problem in report.problems) {
      globals.logger.printError(problem);
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

    globals.logger.printStatus('Resolved against scribe ${sdk.version} in ${sdk.root}');
    for (final MapEntry<String, String> held in resolution.imports.entries) {
      globals.logger.printStatus('  ${held.key} ${held.value}');
    }
    globals.logger.printStatus('');
    globals.logger.printStatus('Written to ${resolution.file}, which git ignores and nobody edits.');
    globals.logger.printStatus(
      'Every package here now resolves through ${resolution.config}, which git ignores; the editor '
      'reads it on its own.',
    );

    return const ScribeCommandResult.success();
  }

  String _lineOf(ForgeEntry entry, {required bool dryRun}) {
    final String path = '$configurationDirectoryName/${entry.name}.yaml';

    return switch (entry.verdict) {
      ForgeVerdict.written => '  + $path${dryRun ? '   missing' : '   written, module defaults'}',
      ForgeVerdict.kept => '  ~ $path   already there, left as it is',
      ForgeVerdict.orphaned => '  ! $path   nothing depends on ${entry.name} any more',
    };
  }

  String _summaryOf(ForgeReport report, {required bool dryRun}) {
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
