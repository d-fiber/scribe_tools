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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/doctor/machine_section.dart';
import 'package:scribe_tools/src/commands/doctor/project_section.dart';
import 'package:scribe_tools/src/commands/doctor/report.dart';
import 'package:scribe_tools/src/commands/doctor/tools_section.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/tools.dart';
import 'package:scribe_tools/src/updates.dart';
import 'package:scribe_tools/src/version.dart';

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
      : Finding.note('scribe $here, $newer is available', hint: 'Run `scribe upgrade` to get it.');
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
/// what to type next is in it: the install line under the tool, and
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
