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
import 'package:scribe/src/secrets.dart';

/// The changes one run of `scribe secrets` was asked to make.
///
/// Parsing is separated from applying so that a bad name is refused before the
/// store is opened: a run that is going to fail should fail before it has
/// decrypted anything.
class SecretEdits {
  const SecretEdits({required this.additions, required this.removals});

  /// The edits spelled by the `--set` and `--unset` values of one run.
  ///
  /// Throws a [UsageError] when an assignment has no `=`, or when either flag
  /// names something that is not a secret name.
  factory SecretEdits.parse({required List<String> set, required List<String> unset}) => SecretEdits(
    additions: set.map(SecretAssignment.parse).toList(),
    removals: unset.map(_validName).toList(),
  );

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
      '"$name" is not a secret name — use uppercase letters, digits and underscore, starting with a letter.',
      command: 'secrets',
    );
  }
}

/// What a set of [SecretEdits] actually changed once applied.
class AppliedEdits {
  const AppliedEdits({required this.written, required this.removed, required this.absent});

  /// The names that were set, whether or not they already held a value.
  final List<String> written;

  /// The names that were removed, which had a value before.
  final List<String> removed;

  /// The names a removal was asked for that were not set to begin with.
  final List<String> absent;
}
