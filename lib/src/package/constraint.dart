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

/// The form a constraint is written in.
///
/// Two forms and no others: a caret, which accepts everything up to the next
/// version allowed to break what it published, and three numbers, which accept
/// that version alone. A range spelled with bounds is refused, because a package
/// that needs one is a package the framework has already let drift.
final RegExp _accepted = RegExp(r'^\^?\d+\.\d+\.\d+$');

/// The constraint a package writes against something it does not version itself.
///
/// It is what a dependency on a third party is written as, because the checkout
/// pins every one of those in its own map and a package naming a second version
/// would be a second place for the two to disagree. It is also what tells a
/// resolver which of the two kinds of dependency it is reading: a name carrying a
/// version is a package, a name carrying this is a specifier the checkout answers.
const String kAny = 'any';

/// What is wrong with [constraint], in the sentence a caller prints, or null.
///
/// The sentence is built here rather than at each call site so that the rule and
/// its wording move together, the way a name's does in `name.dart`.
String? constraintProblem(String constraint) {
  if (constraint == kAny || _accepted.hasMatch(constraint)) return null;

  return '"$constraint" is not a constraint. Write a caret and three numbers to accept everything '
      'up to the next breaking version, as in "^1.2.0", three numbers alone to accept that one, or '
      '"$kAny" for something the checkout pins.';
}

/// Whether [constraint] accepts [version], the two written as a package writes them.
///
/// A caret stops at the next version allowed to break what it published, which is
/// the next major above zero, the next minor below it, and the next patch below
/// that. Anything the manifest would have refused answers false rather than
/// throwing: a caller that skipped the check gets a refusal, not a crash.
bool allows(String constraint, String version) {
  if (constraint == kAny) return true;
  if (constraintProblem(constraint) != null) return false;

  final List<int>? held = _numbers(version);
  if (held == null) return false;

  if (!constraint.startsWith('^')) return constraint == version;

  final List<int> low = _numbers(constraint.substring(1))!;
  final List<int> high = low[0] != 0
      ? <int>[low[0] + 1, 0, 0]
      : low[1] != 0
      ? <int>[0, low[1] + 1, 0]
      : <int>[0, 0, low[2] + 1];

  return _atLeast(held, low) && !_atLeast(held, high);
}

List<int>? _numbers(String text) {
  final List<String> parts = text.split('.');
  if (parts.length != 3) return null;

  final List<int> held = <int>[];
  for (final String part in parts) {
    final int? number = int.tryParse(part);
    if (number == null) return null;
    held.add(number);
  }

  return held;
}

bool _atLeast(List<int> left, List<int> right) {
  for (int index = 0; index < 3; index++) {
    if (left[index] != right[index]) return left[index] > right[index];
  }
  return true;
}
