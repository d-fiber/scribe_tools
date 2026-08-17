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

import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project_templates.dart';
import 'package:scribe/src/sdk_target.dart';

/// Everything `scribe create` prints once the project is on disk.
class CreateReport {
  const CreateReport();

  /// Lists [files], as they were really written.
  ///
  /// The list comes from the scaffold rather than from a list kept beside it,
  /// so what is shown and what exists cannot drift apart.
  void wrote(List<String> files) {
    globals.logger.printStatus('');
    for (final String file in files) {
      globals.logger.printStatus('  $file');
    }
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
        'There is no template for the ${target.name} SDK in ${templates.path}, so only the files '
        'shared by every project were written. Add ${target.name}/ next to common/ to fix that.',
      );
      globals.logger.printStatus('');
    }

    if (target.caveat case final String caveat) {
      globals.logger.printWarning('The ${target.name} SDK is not usable yet: $caveat');
      globals.logger.printStatus('');
    }
  }

  /// Names the next command to run.
  ///
  /// Nothing is chained automatically: a `create` that silently ran a generator
  /// would hide where the generated files came from.
  void nextStep(String projectName) {
    globals.logger.printStatus(
      'Next: cd $projectName, fill config.yaml, then run `scribe gen routes`.',
      emphasis: true,
    );
  }
}
