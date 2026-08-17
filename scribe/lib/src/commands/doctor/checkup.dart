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

import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/commands/doctor/machine_section.dart';
import 'package:scribe/src/commands/doctor/project_section.dart';
import 'package:scribe/src/commands/doctor/report.dart';
import 'package:scribe/src/commands/doctor/tools_section.dart';
import 'package:scribe/src/framework.dart';
import 'package:scribe/src/tools.dart';
import 'package:scribe/src/updates.dart';
import 'package:scribe/src/version.dart';

/// The three sections, read from the machine and the directory as they are now.
///
/// It is a function and not a list because it is read twice in a row by
/// `--rescue`, and the second reading has to see what the first one repaired.
Future<List<DoctorSection>> diagnose({required bool assumeYes}) async {
  final PackageManager? manager = PackageManager.detect();

  return <DoctorSection>[
    machineSection(manager),
    toolsSection(manager, assumeYes: assumeYes).plus(await frameworkFinding()),
    projectSection(),
  ];
}

/// The framework's own line, under the tools it sits among.
///
/// `doctor` is the one place a new version is announced without a line of its
/// own: every other command ends with the notice, and printing it here as well
/// would say the same thing twice on the same screen.
///
/// Null when there is no checkout to speak of, since a version nobody has is
/// not a finding.
Future<Finding?> frameworkFinding() async {
  final Framework? framework = Framework.locate();
  if (framework == null) return null;

  final Version? here = framework.version;
  if (here == null) {
    return const Finding.note('scribe VERSION does not read as a version');
  }

  if (!framework.isClone) return Finding.ok('scribe $here');

  final Version? newer = await pendingUpdate(framework);
  scheduleFetch(framework);

  return newer == null
      ? Finding.ok('scribe $here')
      : Finding.note('scribe $here — $newer is available', hint: 'Run `scribe upgrade` to get it.');
}

/// Stops [invocation] before it starts when one of [everyTool] is not installed.
///
/// Every command goes through this, not only the ones naming a tool in
/// `requiredTools`: nothing this tool writes is worth anything on a machine
/// without `deno`, and a run that fails three steps in leaves half a project
/// behind. The check itself is four lookups on `PATH` and starts no process.
///
/// Nothing is printed when all four are there, so the usual run is unchanged.
/// When one is missing the whole report is printed, sections included, because
/// what to type next is in it — the install line under the tool, and
/// `scribe doctor --rescue` under the report.
///
/// Throws a [ToolExit] carrying [invocation], so what is on screen says which
/// command gave up as well as why.
Future<void> ensureToolsAreInstalled(String invocation, {required bool assumeYes}) async {
  final DoctorSection tools = toolsSection(PackageManager.detect(), assumeYes: assumeYes);
  if (tools.isGood) return;

  printReport(await diagnose(assumeYes: assumeYes));
  throwToolExit('$invocation needs every tool above, and stopped before doing anything.');
}
