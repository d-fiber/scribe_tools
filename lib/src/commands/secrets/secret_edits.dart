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
import 'package:scribe_tools/src/secrets.dart';

/// The changes one run of `scribe secrets` was asked to make.
///
/// Parsing is separated from applying so that a bad name is refused before the
/// store is opened: a run that is going to fail should fail before it has
/// decrypted anything.
class SecretEdits {
  /// Holds the [additions] and [removals] one run was asked for.
  const SecretEdits({required this.additions, required this.removals});

  /// The edits spelled by the `--set` and `--unset` values of one run.
  ///
  /// Throws a [UsageError] when an assignment has no `=`, or when either flag
  /// names something that is not a secret name.
  factory SecretEdits.parse({required List<String> set, required List<String> unset}) =>
      SecretEdits(additions: set.map(SecretAssignment.parse).toList(), removals: unset.map(_validName).toList());

  /// The secrets to write, in the order they were given.
  final List<SecretAssignment> additions;

  /// The names to remove, in the order they were given.
  final List<String> removals;

  /// Whether this run was asked to change nothing, and so only has to list.
  bool get isEmpty => additions.isEmpty && removals.isEmpty;

  /// Carries out these edits on [secrets], and reports what really changed.
  ///
  /// [secrets] is modified in place. A removal of a name that was not set
  /// changes nothing and comes back under [AppliedEdits.absent].
  AppliedEdits applyTo(Map<String, String> secrets) {
    final List<String> removed = <String>[];
    final List<String> absent = <String>[];

    for (final String name in removals) {
      (secrets.remove(name) == null ? absent : removed).add(name);
    }
    for (final SecretAssignment addition in additions) {
      secrets[addition.name] = addition.value;
    }

    return AppliedEdits(
      written: <String>[for (final SecretAssignment addition in additions) addition.name],
      removed: removed,
      absent: absent,
    );
  }

  static String _validName(String raw) {
    final String name = raw.trim();
    if (secretName.hasMatch(name)) return name;

    throwUsageError(
      '"$name" is not a secret name. Use uppercase letters, digits and underscore, starting with a letter.',
      command: 'secrets',
    );
  }
}

/// What a set of [SecretEdits] actually changed once applied.
class AppliedEdits {
  /// Holds what a run changed: [written], [removed], and the [absent] it could not remove.
  const AppliedEdits({required this.written, required this.removed, required this.absent});

  /// The names that were set, whether or not they already held a value.
  final List<String> written;

  /// The names that were removed, which had a value before.
  final List<String> removed;

  /// The names a removal was asked for that were not set to begin with.
  final List<String> absent;
}
