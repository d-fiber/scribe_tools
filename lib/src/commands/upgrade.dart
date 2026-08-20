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
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/version.dart';

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
