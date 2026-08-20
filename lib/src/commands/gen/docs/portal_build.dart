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

import 'package:file/file.dart';
import 'package:fiber_shell/fiber_shell.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Rebuilds the documentation portal from the manifest just written.
///
/// The whole generated `docs/` directory comes out of this one command: the
/// specifications, the manifest, and the static site that displays them.
///
/// Dependencies are installed only when `node_modules/` is absent, so the
/// common case is one build and not a reinstall.
///
/// Throws a [ToolExit] when either step fails. A portal built from a failed
/// install is worse than none: it shows the previous run's output as if it were
/// current.
Future<void> buildPortal(Directory root) async {
  final Directory portal = globals.fs.directory(p.join(root.path, 'scribe/web/developers_docs'));
  final Directory workspace = portal.parent;

  if (!globals.fs.directory(p.join(workspace.path, 'node_modules')).existsSync()) {
    globals.logger.printStatus('portal: installing workspace dependencies (npm ci)...');

    final ShellResult install = await Npm.ci().output(cwd: workspace.path);
    if (install.failed) throwToolExit('portal: npm ci failed: ${install.error}');
  }

  final ShellResult build = await Npm.run().script('build').output(cwd: portal.path);
  if (build.failed) throwToolExit('portal: build failed: ${build.error}');

  globals.logger.printStatus('portal: ${globals.project.generatedDirectoryName}/docs/dist/ rebuilt');
}
