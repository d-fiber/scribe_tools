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

import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;

/// What a doctor's line is, which decides whether it is printed and counted.
enum FindingKind {
  /// Something that works. Only `-v` prints it, and nothing is wrong.
  ok,

  /// Something worth saying that is not a problem, printed either way.
  note,

  /// Something that does not work. Printed, counted, and possibly repaired.
  problem,
}

/// One line of a section, and what the user can do about it.
class Finding {
  const Finding.ok(this.message) : kind = FindingKind.ok, hint = null, repair = null;

  const Finding.note(this.message, {this.hint}) : kind = FindingKind.note, repair = null;

  const Finding.problem(this.message, {this.hint, this.repair}) : kind = FindingKind.problem;

  /// What was found, in one sentence.
  final String message;

  /// What kind of line this is.
  final FindingKind kind;

  /// What to do about it, printed under [message].
  ///
  /// It names a command whenever one exists, the way `flutter doctor` does —
  /// the point of a diagnosis is the next thing to type.
  final String? hint;

  /// What `--rescue` runs to repair it, null when nothing can.
  ///
  /// A manifest field nobody filled in and a key nobody has cannot be repaired
  /// by a machine. Only [hint] is left for those, and that is the honest answer.
  final Future<void> Function()? repair;

  /// Whether this line is one of the problems the report counts.
  bool get isProblem => kind == FindingKind.problem;
}

/// How much of a section is printed when nothing in it is wrong.
///
/// It only decides the quiet case. A section holding a problem or a note always
/// prints it, and `-v` prints everything whatever this says.
enum SectionDetail {
  /// The bracketed line alone, with [DoctorSection.summary] in parentheses.
  summary,

  /// The bracketed line and every finding under it.
  full,

  /// Nothing at all.
  none,
}

/// One block of the report, `flutter doctor` style.
class DoctorSection {
  const DoctorSection({
    required this.title,
    required this.findings,
    this.summary,
    this.detail = SectionDetail.summary,
  });

  /// The name of the block, on the bracketed line.
  final String title;

  /// What goes in parentheses after [title], usually what was found.
  final String? summary;

  /// What is left of this section when it has nothing to report.
  final SectionDetail detail;

  /// Everything the section found, in the order it is printed.
  final List<Finding> findings;

  /// Whether nothing in here is a problem.
  bool get isGood => !findings.any((Finding finding) => finding.isProblem);

  /// Whether every line of this section is one that works.
  bool get hasNothingToReport => findings.every((Finding finding) => finding.kind == FindingKind.ok);

  /// The problems `--rescue` can do something about.
  List<Finding> get repairable =>
      findings.where((Finding finding) => finding.isProblem && finding.repair != null).toList();
}

/// Prints [sections] and the line that closes them, and returns whether all is well.
///
/// A section that is fine collapses to its bracketed line: its details are
/// traces, printed by `-v` and nothing else. What is wrong is always shown,
/// with the hint under it, because that is what the command is read for.
bool printReport(List<DoctorSection> sections) {
  for (final DoctorSection section in sections) {
    _printSection(section);
  }

  final List<DoctorSection> wrong = sections.where((DoctorSection section) => !section.isGood).toList();
  globals.logger.printStatus('');

  if (wrong.isEmpty) {
    globals.logger.printStatus('${globals.terminal.successMark} No issues found!', emphasis: true);
    return true;
  }

  final String categories = wrong.length == 1 ? 'category' : 'categories';
  globals.logger.printStatus(
    '${globals.terminal.warningMark} Doctor found issues in ${wrong.length} $categories.',
    emphasis: true,
  );

  if (sections.any((DoctorSection section) => section.repairable.isNotEmpty)) {
    globals.logger.printStatus('');
    globals.logger.printStatus('Run `scribe doctor --rescue` to fix what can be fixed from here.');
  }

  return false;
}

void _printSection(DoctorSection section) {
  final bool verbose = globals.logger.isVerbose;

  if (!verbose && section.detail == SectionDetail.none && section.hasNothingToReport) return;

  final String mark = section.isGood ? globals.terminal.successMark : globals.terminal.warningMark;
  final String summary = section.summary == null ? '' : ' (${section.summary})';

  globals.logger.printStatus('[$mark] ${section.title}$summary', emphasis: true);

  for (final Finding finding in section.findings) {
    if (finding.kind == FindingKind.ok && !verbose && section.detail != SectionDetail.full) continue;

    _printFinding(finding);
  }
}

void _printFinding(Finding finding) {
  switch (finding.kind) {
    case FindingKind.ok:
      globals.logger.printStatus('    ${globals.terminal.successMark} ${finding.message}');
    case FindingKind.note:
      globals.logger.printStatus('    • ${finding.message}');
    case FindingKind.problem:
      globals.logger.printStatus('    ${globals.terminal.errorMark} ${finding.message}', color: TerminalColor.yellow);
  }

  if (finding.hint case final String hint) globals.logger.printStatus('      $hint');
}
