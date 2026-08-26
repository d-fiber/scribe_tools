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
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/project_templates.dart';
import 'package:scribe_tools/src/sdk_target.dart';

/// Everything `scribe create` prints once the project is on disk.
///
/// The shape is the one `flutter create` ends on: how much was written, then
/// the commands to type next, one per line behind a `$` so a reader can copy
/// them, then where the code they will edit sits.
class CreateReport {
  /// Holds nothing, since every sentence is built from what it is handed.
  const CreateReport();

  /// Says how many of [files] were written, and traces which ones.
  ///
  /// The count comes from the scaffold rather than from a list kept beside it,
  /// so what is shown and what exists cannot drift apart. The paths themselves
  /// only show under `-v`: nine of them between the command and the next step
  /// are read as noise.
  void wrote(List<String> files) {
    for (final String file in files) {
      globals.logger.printTrace('wrote $file');
    }

    globals.logger.printStatus('');
    globals.logger.printStatus('Wrote ${files.length} ${files.length == 1 ? 'file' : 'files'}.');
    globals.logger.printStatus('');
  }

  /// Says what is missing, once the project is created and the choice is made.
  ///
  /// Creating a project on a target that is not ready works, and this is where
  /// the user is told what that costs. It comes afterwards on purpose: in the
  /// menu it would be noise, here it is the next thing to deal with.
  void caveats(SdkTarget target, ProjectTemplates templates) {
    if (!templates.has(target.name)) {
      globals.logger.printWarning(
        'There is no template for the ${target.label} SDK in ${templates.path}, so only the files '
        'shared by every project were written. Add ${target.name}/ next to common/ to fix that.',
      );
      globals.logger.printStatus('');
    }

    if (target.caveat case final String caveat) {
      globals.logger.printWarning('The ${target.label} SDK is not usable yet: $caveat');
      globals.logger.printStatus('');
    }
  }

  /// Names the commands to run next, and the files [projectName] is edited through.
  ///
  /// Nothing is chained automatically: a `create` that silently ran a generator
  /// would hide where the generated files came from.
  ///
  /// The command named here is `doctor`, not a generator. `gen` is meant to
  /// disappear once generation stops being something a user asks for, and the
  /// worst message to leave behind is the first one everybody reads, sending
  /// them to a command that no longer exists.
  void nextStep(String projectName, SdkTarget target) {
    globals.logger.printStatus('All done!', emphasis: true);
    globals.logger.printStatus('');
    globals.logger.printStatus('In order to work on your project, type:');
    globals.logger.printStatus('');
    globals.logger.printStatus('  \$ cd $projectName');
    globals.logger.printStatus(r'  $ scribe doctor');
    globals.logger.printStatus('');
    globals.logger.printStatus(
      'Your project is declared in $projectName/${Project.configFileName}, and '
      'every node it serves is a directory under $projectName/lib/.',
    );
  }
}
