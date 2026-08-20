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
  DoctorCommand() {
    argParser.addFlag(
      rescueOption,
      abbr: 'r',
      negatable: false,
      help:
          'Repair what can be repaired from here: install the missing tools with the package '
          'manager of this machine, and create the directories a project is missing. '
          'What is left is what only a human can write.',
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

    return printReport(await _look()) ? const ScribeCommandResult.success() : const ScribeCommandResult.warning();
  }

  Future<List<DoctorSection>> _look() => diagnose(assumeYes: ScribeCommandRunner.assumesYes(globalResults));

  /// Runs every repair the sections offered, then lets the report say what is left.
  ///
  /// Nothing is listed twice on purpose: the report printed right after already
  /// names every problem still standing, so a list of what could not be
  /// repaired would be the same lines a few rows higher.
  Future<void> _rescue() async {
    final List<Finding> repairs = <Finding>[
      for (final DoctorSection section in await _look()) ...section.repairable,
    ];

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
