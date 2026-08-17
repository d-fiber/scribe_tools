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

import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';
import 'package:scribe/src/scribe_manifest.dart';
import 'package:scribe/src/secrets.dart';

/// Reports the project here, and returns whether it is ready to be worked on.
///
/// Being outside a project is not a failure. This command prepares a machine as
/// much as it checks a project, and a machine is prepared before there is one.
///
/// This is also the only place the manifest's problems are shown without the
/// command refusing to run: everywhere else they throw.
bool reportProject() {
  globals.logger.printStatus('Project', emphasis: true);

  final Project? here = Project.currentOrNull;
  if (here == null) {
    globals.logger.printStatus('  no ${Project.configFileName} here — this is not a project root');
    return true;
  }

  final List<String> problems = <String>[
    for (final String entry in here.missingEntries) '$entry is missing',
    for (final ManifestProblem problem in here.manifest.problems) '$problem',
    ..._secretsProblems(here),
  ];

  for (final String problem in problems) {
    globals.logger.printStatus('  ${globals.terminal.warningMark} $problem', color: TerminalColor.yellow);
  }

  if (problems.isEmpty) {
    globals.logger.printStatus('  ${globals.terminal.successMark} ${here.name}');
  }

  return problems.isEmpty;
}

/// The one secrets problem worth reporting: a store nothing can open.
///
/// A project without a `secrets.age` is fine — most are. A project with one and
/// no key is stuck, and the failure would otherwise only show up at the command
/// that needed a secret.
List<String> _secretsProblems(Project project) {
  final SecretsStore store = SecretsStore.forProject(project);
  if (!store.exists || store.identityLines.isNotEmpty) return const <String>[];

  return <String>['${SecretsStore.fileName} is here, but no key opens it'];
}
