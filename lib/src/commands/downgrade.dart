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

import 'package:interact/interact.dart' as interact;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/self/version.dart';
import 'package:scribe_tools/src/tools.dart';

/// Puts the framework checkout back on a version it was on before.
///
/// The list is every version older than the one here, newest first, read from
/// the history of `VERSION`. Picking one leaves the checkout on a detached
/// head, and `scribe upgrade` is the way back.
class DowngradeCommand extends ScribeCommand {
  /// Takes no option: the version is picked from the list it prints.
  DowngradeCommand();

  @override
  String get name => 'downgrade';

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.git];

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
    globals.logger.printStatus('${globals.terminal.successMark} scribe is now at ${wanted.version}, down from $here.');
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
