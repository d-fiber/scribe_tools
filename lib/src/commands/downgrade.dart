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

import 'package:interact/interact.dart' as interact;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/version.dart';

/// Puts the framework checkout back on a version it was on before.
///
/// The list is every version older than the one here, newest first, read from
/// the history of `VERSION`. Picking one leaves the checkout on a detached
/// head, and `scribe upgrade` is the way back.
class DowngradeCommand extends ScribeCommand {
  DowngradeCommand();

  @override
  String get name => 'downgrade';

  @override
  String get description => 'Put the scribe checkout back on an older version.';

  @override
  String get invocation => 'scribe downgrade [version]';

  @override
  bool get requiresProject => false;

  /// The version this prints is the one it just moved to.
  @override
  bool get checksVersion => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Framework framework = requireCheckout();
    final Version? here = framework.version;

    await requireCleanCheckout(framework);

    final List<Release> older = await _older(framework, here);
    if (older.isEmpty) {
      throwToolExit(
        'There is nothing to go back to: $here is the oldest version this checkout knows.\n'
        'A shallow clone only carries the commits it was cloned with. Run `git fetch --unshallow` to bring the rest.',
      );
    }

    final Release wanted = _wanted(older);
    if (!await framework.checkout(wanted)) {
      throwToolExit('git could not put the checkout on ${wanted.version}. It is left as it was.');
    }

    globals.logger.printStatus('');
    globals.logger.printStatus(
      '${globals.terminal.successMark} scribe is now at ${wanted.version}, down from $here.',
    );
    globals.logger.printStatus(
      'The checkout is on ${wanted.shortCommit}, off any branch. Run `scribe upgrade` to come back to the newest.',
    );

    return const ScribeCommandResult.success();
  }

  /// Every version behind [here], newest first.
  ///
  /// The current version is left out because it is where the checkout already
  /// is, and so is anything above it: this command only goes back.
  Future<List<Release>> _older(Framework framework, Version? here) async {
    final List<Release> history = await framework.history();
    if (here == null) return history;

    return history.where((Release release) => here.isNewerThan(release.version)).toList();
  }

  /// The version to move to, from the command line or from the menu.
  Release _wanted(List<Release> older) {
    if (argResults?.rest.isNotEmpty ?? false) return _named(requirePositional('version'), older);

    if (!globals.terminal.supportsRawInput) {
      throwToolExit(
        'There is no terminal to open the menu in, so the version has to be named: '
        'scribe downgrade ${older.first.version}',
      );
    }

    final int picked = interact.Select(
      prompt: 'Which version do you want to go back to?',
      options: <String>[for (final Release release in older) _label(release)],
      initialIndex: 0,
    ).interact();

    return older[picked];
  }

  Release _named(String asked, List<Release> older) {
    final Version? wanted = Version.tryParse(asked);

    for (final Release release in older) {
      if (release.version == wanted) return release;
    }

    throwUsageError(
      '"$asked" is not a version this checkout can go back to.\n'
      'It knows: ${older.map((Release release) => release.version).join(', ')}.',
      command: name,
    );
  }

  /// One line of the menu: the version, when it was cut, and its commit.
  String _label(Release release) {
    final String date = release.date == null ? '' : '  ${release.date!.toIso8601String().substring(0, 10)}';

    return '${release.version}$date  ${release.shortCommit}';
  }
}
