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
import 'package:scribe_tools/src/self/codex_updates.dart';
import 'package:scribe_tools/src/self/tool_updates.dart';
import 'package:scribe_tools/src/self/version.dart';
import 'package:scribe_tools/src/tools.dart';

/// Brings the framework checkout, the tool itself and the dashboard to their
/// newest published version, each independently.
///
/// The three are unrelated pieces of software with their own release cadence,
/// so one being unreachable, or already current, never stops the others: a
/// machine with no `curl` still gets its framework fast-forwarded, and a
/// `scribe_codex` with no release yet still lets the tool replace itself.
class UpgradeCommand extends ScribeCommand {
  /// Takes no option: there is one version to move each of the three to, and it is the newest.
  UpgradeCommand();

  @override
  String get name => 'upgrade';

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.git];

  @override
  String get description => 'Bring the checkout, the tool and the dashboard to their newest version.';

  @override
  bool get requiresProject => false;

  /// The versions this prints are the ones it just moved to.
  @override
  bool get checksVersion => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Framework framework = requireCheckout();

    await _upgradeFramework(framework);
    globals.logger.printStatus('');
    await _upgradeTool(framework);
    globals.logger.printStatus('');
    await _upgradeCodex(framework);

    return const ScribeCommandResult.success();
  }

  Future<void> _upgradeFramework(Framework framework) async {
    final Version? before = framework.version;

    await requireCleanCheckout(framework);

    globals.logger.printStatus('Fetching $kOrigin/$kReleaseBranch...');
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

    if (before == after) {
      globals.logger.printStatus('${globals.terminal.successMark} framework is already up to date at $after.');
      return;
    }

    globals.logger.printStatus('${globals.terminal.successMark} framework is now at $after, up from $before.');
  }

  Future<void> _upgradeTool(Framework framework) async {
    final Version? before = installedToolVersion;
    if (before == null) {
      globals.logger.printStatus('scribe (this tool) was not built with a version, so there is nothing to compare.');
      return;
    }

    globals.logger.printStatus('Checking the latest release of scribe_tools...');

    try {
      final Version? latest = await latestToolVersion();
      if (latest == null) {
        globals.logger.printWarning('Could not read the latest release of scribe_tools.');
        return;
      }

      if (!latest.isNewerThan(before)) {
        globals.logger.printStatus(
          '${globals.terminal.successMark} scribe (this tool) is already up to date at $before.',
        );
        return;
      }

      await applyToolUpdate(framework);
      globals.logger.printStatus(
        '${globals.terminal.successMark} scribe (this tool) is now at $latest, up from $before.',
      );
      globals.logger.printStatus('This run keeps answering as $before; the new build answers from the next one.');
    } on ToolExit catch (error) {
      globals.logger.printWarning('scribe (this tool) was not updated: ${error.message}');
    }
  }

  Future<void> _upgradeCodex(Framework framework) async {
    globals.logger.printStatus('Checking the latest release of scribe_codex...');

    try {
      final Version? latest = await latestCodexVersion();
      if (latest == null) {
        globals.logger.printWarning('Could not read the latest release of scribe_codex.');
        return;
      }

      final Version? before = installedCodexVersion(framework);
      if (before != null && !latest.isNewerThan(before)) {
        globals.logger.printStatus('${globals.terminal.successMark} dashboard is already up to date at $before.');
        return;
      }

      await applyCodexUpdate(framework);
      globals.logger.printStatus(
        before == null
            ? '${globals.terminal.successMark} dashboard installed at $latest.'
            : '${globals.terminal.successMark} dashboard is now at $latest, up from $before.',
      );
    } on ToolExit catch (error) {
      globals.logger.printWarning('dashboard was not updated: ${error.message}');
    }
  }
}
