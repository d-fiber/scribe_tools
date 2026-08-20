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
      'Your project is declared in $projectName/${Project.configFileName}, and its code is in '
      '$projectName/lib/${target.entrypointName}.',
    );
  }
}
