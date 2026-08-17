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
import 'package:scribe/src/framework.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/version.dart';

/// Brings the framework checkout to the newest version on the release branch.
///
/// It moves the checkout and nothing else. The tool running this stays the
/// build it was installed as: its binaries come from a rolling release that
/// carries no version, so there is nothing to move them to.
class UpgradeCommand extends ScribeCommand {
  UpgradeCommand();

  @override
  String get name => 'upgrade';

  @override
  String get description => 'Bring the scribe checkout to the newest version.';

  @override
  bool get requiresProject => false;

  /// The version this prints is the one it just moved to.
  @override
  bool get checksVersion => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Framework framework = requireCheckout();
    final Version? before = framework.version;

    await requireCleanCheckout(framework);

    globals.logger.printStatus('Fetching $kOrigin/$kReleaseBranch');
    if (!await framework.fetch()) {
      throwToolExit('Could not reach $kOrigin. The checkout is untouched.');
    }

    if (!await framework.fastForward()) {
      throwToolExit(
        'The checkout could not be moved to $kOrigin/$kReleaseBranch without rewriting it.\n'
        'It carries commits the remote does not have, so it is left as it is.',
      );
    }

    final Version? after = framework.version;
    globals.logger.printStatus('');

    if (before == after) {
      globals.logger.printStatus('${globals.terminal.successMark} scribe is already up to date at $after.');
      return const ScribeCommandResult.success();
    }

    globals.logger.printStatus('${globals.terminal.successMark} scribe is now at $after, up from $before.');
    globals.logger.printStatus('The tools you run are unchanged: they are not versioned with the framework.');

    return const ScribeCommandResult.success();
  }
}
