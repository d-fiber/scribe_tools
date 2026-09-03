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

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/editor_report.dart';
import 'package:scribe_tools/src/package/import_fold.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runtime/editor_projection.dart';

/// Says what an editor needs to do so `@scribe/...` resolves, across every runtime a set of
/// already-forged packages use.
///
/// It never resolves a package itself — that is `scribe forge`'s job — it only reads what forge
/// already left behind and asks each runtime present what an editor needs. An editor is expected
/// to run this, not a person: every directory has to be named on the line, because an editor
/// already knows which packages its workspace holds, and guessing that here would be a second,
/// divergent way of finding them.
class EditorCommand extends ScribeCommand {
  /// Declares `--machine`, the only way this command is meant to be read.
  EditorCommand() {
    argParser.addFlag(
      ScribeCommand.machineOption,
      negatable: false,
      help: 'Print one line of JSON instead of a report: what packages resolved, and what each '
          'runtime present needs an editor to do.',
    );
  }

  @override
  String get name => 'editor';

  @override
  String get description => 'Say what an editor needs to resolve @scribe/... across a set of packages.';

  @override
  String get invocation => 'scribe editor <directory>...';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final List<String> directories = <String>[
      for (final String given in argResults?.rest ?? const <String>[]) p.absolute(given),
    ];
    if (directories.isEmpty) {
      throwToolExit('$invocationName needs at least one <directory>, the packages an editor holds open.');
    }

    final EditorReport report = buildEditorReport(directories);
    final Map<String, Object?> document = editorMachineReport(report);

    if (boolArg(ScribeCommand.machineOption)) {
      printMachine(document);
    } else {
      _printReport(report);
    }

    return (document['ok']! as bool) ? const ScribeCommandResult.success() : const ScribeCommandResult.warning();
  }

  void _printReport(EditorReport report) {
    final int resolved = report.packages.where((EditorPackage package) => package.resolved).length;
    globals.logger.printStatus(
      '$resolved of ${report.packages.length} package(s) resolved, across ${report.projections.length} runtime(s).',
    );

    for (final EditorPackage package in report.packages) {
      if (!package.resolved) globals.logger.printStatus('  ${package.directory} has no current resolution.');
    }

    for (final MapEntry<String, List<ImportConflict>> group in report.conflicts.entries) {
      for (final ImportConflict conflict in group.value) {
        globals.logger.printError(
          '"${conflict.specifier}" is answered two ways under ${group.key}: ${conflict.kept}, and '
          '${conflict.dropped} by ${conflict.by}. Resolve both packages against the same checkout.',
        );
      }
    }

    for (final MapEntry<String, EditorProjection> entry in report.projections.entries) {
      if (entry.value.languageServer case final LanguageServerProjection server) {
        globals.logger.printStatus('${entry.key}: hand ${server.configFileName} to ${server.extensionId}.');
      }
      for (final String written in entry.value.filesWritten) {
        globals.logger.printStatus('${entry.key}: wrote $written.');
      }
    }
  }
}

/// [report], in the shape `editor --machine` prints.
///
/// A top-level function and not a method on [EditorCommand], the same reason
/// `doctorMachineReport` is one: `scribe daemon` builds the same document from the same
/// [EditorReport] a request handler already has.
Map<String, Object?> editorMachineReport(EditorReport report) {
  final bool ok = report.packages.every((EditorPackage package) => package.resolved) && report.conflicts.isEmpty;

  return <String, Object?>{
    'command': 'editor',
    'ok': ok,
    'packages': <Object?>[
      for (final EditorPackage package in report.packages)
        <String, Object?>{'directory': package.directory, 'runtime': package.runtime, 'resolved': package.resolved},
    ],
    'conflicts': <Object?>[
      for (final MapEntry<String, List<ImportConflict>> group in report.conflicts.entries)
        for (final ImportConflict conflict in group.value)
          <String, Object?>{
            'runtime': group.key,
            'specifier': conflict.specifier,
            'kept': conflict.kept,
            'dropped': conflict.dropped,
            'by': conflict.by,
          },
    ],
    'languageServers': <Object?>[
      for (final EditorProjection projection in report.projections.values)
        if (projection.languageServer case final LanguageServerProjection server)
          <String, Object?>{
            'runtime': server.runtime,
            'extensionId': server.extensionId,
            'enableSettingKey': server.enableSettingKey,
            'configSettingKey': server.configSettingKey,
            'additionalSettings': server.additionalSettings,
            'configFileName': server.configFileName,
            'configContents': server.configContents,
            'restartCommands': server.restartCommands,
          },
    ],
    'filesWritten': <Object?>[
      for (final EditorProjection projection in report.projections.values) ...projection.filesWritten,
    ],
  };
}
