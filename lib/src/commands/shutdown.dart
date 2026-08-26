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

import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/stack/compose.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/stack/stack_manifest.dart';
import 'package:scribe_tools/src/tools.dart';

/// Stops the stack of this project and removes what it created.
///
/// It reads what `up` recorded rather than assembling again, because stopping a
/// stack must not depend on the selection still rendering: a project whose
/// `config.yaml` has changed since it was started would otherwise assemble a
/// different stack and stop nothing.
class ShutdownCommand extends ScribeCommand {
  /// Declares the flag that decides whether the stored data goes too.
  ShutdownCommand() {
    argParser.addFlag(
      'clear',
      abbr: 'c',
      negatable: false,
      help: 'Also remove the stored data, which is what empties the database.',
    );
  }

  @override
  String get name => 'shutdown';

  @override
  String get description => 'Stop this project and remove what running it created.';

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final StackManifest manifest = StackManifest.read(StackLocation(project: project).manifest);
    globals.logger.printStatus('Stopping ${manifest.projectName}...');

    return await Compose(manifest).down(volumes: boolArg('clear')) == 0
        ? const ScribeCommandResult.success()
        : const ScribeCommandResult.fail();
  }
}
