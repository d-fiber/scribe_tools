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
import 'package:scribe/src/commands/secrets/secret_edits.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/secrets.dart';

/// Everything `scribe secrets` prints, kept out of the command itself.
///
/// The command decides what happened; this decides how it reads. Values are
/// never printed, only names — a secret shown on a terminal ends up in a
/// scrollback buffer and in a screenshot.
class SecretsReport {
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
