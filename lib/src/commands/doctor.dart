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

import 'package:scribe_tools/src/commands/doctor/checkup.dart';
import 'package:scribe_tools/src/commands/doctor/report.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';

/// Reports what this machine and this project are missing.
///
/// It fixes nothing unless [rescueOption] is passed, and then only what a
/// machine can fix on its own.
class DoctorCommand extends ScribeCommand {
  /// Declares `--rescue`, which is what turns a report into a repair.
  DoctorCommand() {
    argParser
      ..addFlag(
        rescueOption,
        abbr: 'r',
        negatable: false,
        help:
            'Repair what can be repaired from here: install the missing tools with the package '
            'manager of this machine, and create the directories a project is missing. '
            'What is left is what only a human can write.',
      )
      ..addFlag(
        ScribeCommand.machineOption,
        negatable: false,
        help: 'Print one line of JSON instead of the report, one object per section.',
      );
  }

  /// The flag that turns the diagnosis into a repair.
  static const String rescueOption = 'rescue';

  @override
  String get name => 'doctor';

  @override
  String get description => 'Report what this machine and this project are missing.';

  @override
  String get invocation => 'scribe doctor [--rescue]';

  @override
  bool get requiresProject => false;

  /// This command is the check every other one opens with.
  ///
  /// Letting it run would print the report, refuse, and never reach the flag
  /// that repairs what the report just named.
  @override
  bool get checksMachine => false;

  /// The report carries the version line itself, under the tools.
  @override
  bool get checksVersion => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    if (boolArg(rescueOption)) await _rescue();

    final List<DoctorSection> sections = await _look();
    final bool ok = sections.every((DoctorSection section) => section.isGood);

    if (boolArg(ScribeCommand.machineOption)) {
      printMachine(_machineReport(sections, ok: ok));
    } else {
      printReport(sections);
    }

    return ok ? const ScribeCommandResult.success() : const ScribeCommandResult.warning();
  }

  Future<List<DoctorSection>> _look() => diagnose(assumeYes: ScribeCommandRunner.assumesYes(globalResults));

  /// [sections], in the shape `--machine` prints: one object per section, one
  /// per finding underneath it. Nothing here decides what is shown or hidden
  /// the way [printReport] does — every finding goes, `-v` or not, because a
  /// caller parsing this is the one deciding what to do with it.
  Map<String, Object?> _machineReport(List<DoctorSection> sections, {required bool ok}) => <String, Object?>{
    'command': 'doctor',
    'ok': ok,
    'sections': <Object?>[
      for (final DoctorSection section in sections)
        <String, Object?>{
          'title': section.title,
          'summary': section.summary,
          'ok': section.isGood,
          'findings': <Object?>[
            for (final Finding finding in section.findings)
              <String, Object?>{
                'kind': finding.kind.name,
                'message': finding.message,
                'hint': finding.hint,
                'repairable': finding.repair != null,
              },
          ],
        },
    ],
  };

  /// Runs every repair the sections offered, then lets the report say what is left.
  ///
  /// Nothing is listed twice on purpose: the report printed right after already
  /// names every problem still standing, so a list of what could not be
  /// repaired would be the same lines a few rows higher.
  Future<void> _rescue() async {
    final List<Finding> repairs = <Finding>[for (final DoctorSection section in await _look()) ...section.repairable];

    if (repairs.isEmpty) {
      globals.logger.printStatus('There is nothing --rescue can do from here.', emphasis: true);
      globals.logger.printStatus('');
      return;
    }

    globals.logger.printStatus('Repairing what can be repaired from here.', emphasis: true);

    for (final Finding repair in repairs) {
      globals.logger.printStatus('  ${repair.message}');
      await repair.repair!();
    }

    globals.logger.printStatus('');
  }
}
