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
