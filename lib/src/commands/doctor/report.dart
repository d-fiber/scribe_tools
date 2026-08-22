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

import 'package:scribe_tools/src/base/terminal.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

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
  /// Reports [message] as something that works.
  const Finding.ok(this.message) : kind = FindingKind.ok, hint = null, repair = null;

  /// Reports [message] as worth reading without being a problem, [hint] saying more.
  const Finding.note(this.message, {this.hint}) : kind = FindingKind.note, repair = null;

  /// Reports [message] as broken, [hint] saying more and [repair] able to fix it.
  const Finding.problem(this.message, {this.hint, this.repair}) : kind = FindingKind.problem;

  /// What was found, in one sentence.
  final String message;

  /// What kind of line this is.
  final FindingKind kind;

  /// What to do about it, printed under [message].
  ///
  /// It names a command whenever one exists, the way `flutter doctor` does,
  /// because the point of a diagnosis is the next thing to type.
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
  /// Gathers [findings] under [title], showing as much of them as [detail] asks for.
  const DoctorSection({required this.title, required this.findings, this.summary, this.detail = SectionDetail.summary});

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

  /// This section with [extra] appended, or this one when there is nothing to add.
  DoctorSection plus(Finding? extra) => extra == null
      ? this
      : DoctorSection(title: title, summary: summary, detail: detail, findings: <Finding>[...findings, extra]);

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
