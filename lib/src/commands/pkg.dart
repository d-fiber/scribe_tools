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

import 'package:scribe_tools/src/commands/pkg/analyze.dart';
import 'package:scribe_tools/src/commands/pkg/create.dart';
import 'package:scribe_tools/src/commands/pkg/get.dart';
import 'package:scribe_tools/src/commands/pkg/test.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Everything done to a package of the framework: writing one, and reading what is wrong with it.
///
/// This family works on the framework and never on a project, which is why none
/// of it declares [ScribeCommand.requiresProject]. What it resolves against is
/// the checkout `package/sdk.dart` finds, not the one a project vendors.
class PkgCommand extends ScribeCommandGroup {
  /// Gathers everything done to a package behind the word `pkg`.
  PkgCommand() {
    addSubcommand(PkgAnalyzeCommand());
    addSubcommand(PkgCreateCommand());
    addSubcommand(PkgGetCommand());
    addSubcommand(PkgTestCommand());
  }

  @override
  String get name => 'pkg';

  @override
  String get description => 'Write a package, and read what is wrong with the ones already there.';

  @override
  String get invocation => 'scribe pkg <command> [arguments]';
}
