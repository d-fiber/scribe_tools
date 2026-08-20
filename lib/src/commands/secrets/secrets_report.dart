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
import 'package:scribe_tools/src/commands/secrets/secret_edits.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/secrets.dart';

/// Everything `scribe secrets` prints, kept out of the command itself.
///
/// The command decides what happened; this decides how it reads. Values are
/// never printed, only names, because a secret shown on a terminal ends up in a
/// scrollback buffer and in a screenshot.
class SecretsReport {
  /// Holds nothing, since every sentence is built from what it is handed.
  const SecretsReport();

  /// Lists [names], or says how to add the first one when there are none.
  void stored(List<String> names) {
    if (names.isEmpty) {
      globals.logger.printStatus('No secret yet. Add one with `scribe secrets --set NAME=VALUE`.');
      return;
    }

    for (final String name in names) {
      globals.logger.printStatus('  $name');
    }
  }

  /// Names the variables [configPath] reads that nothing has set.
  ///
  /// These are the ones that will fail at the next command rather than here,
  /// which is why listing them is worth a warning exit status.
  void unsetReferences(List<String> names, {required String configPath}) {
    globals.logger.printStatus('');
    globals.logger.printStatus('$configPath reads secrets nobody has set:', emphasis: true);

    for (final String name in names) {
      globals.logger.printStatus('  $name', color: TerminalColor.yellow);
    }
  }

  /// Warns that [names] were asked to be removed and were not set.
  ///
  /// Said before the store is written, where it reads as a remark about the
  /// command line rather than about the result.
  void nothingToRemove(List<String> names) {
    for (final String name in names) {
      globals.logger.printWarning('$name was not set, nothing to remove.');
    }
  }

  /// Reports what one run changed, a line per name.
  void changed(AppliedEdits edits) {
    for (final String name in edits.written) {
      globals.logger.printStatus('${globals.terminal.successMark} set $name');
    }
    for (final String name in edits.removed) {
      globals.logger.printStatus('${globals.terminal.successMark} unset $name');
    }
  }

  /// Warns that [store] now hangs on a key that exists in one place only.
  void newKey(SecretsStore store) {
    globals.logger.printStatus('');
    globals.logger.printStatus('A new key was created in ${store.keyFile.path}.', emphasis: true);
    globals.logger.printStatus(
      'It is the only thing that opens ${store.file.path}. Back it up, and never commit it.',
      color: TerminalColor.yellow,
    );
    globals.logger.printStatus('');
  }
}
