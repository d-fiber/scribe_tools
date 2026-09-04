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

import 'dart:convert';

import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/forge/deploy/declared_deploy.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';
import 'package:scribe_tools/src/templates.dart';

/// The bridge script this tool ships, relative to its own `scripts/`.
///
/// Sits next to the binary rather than inside the checkout, the same reason
/// `kBridgeScriptPathSegments` in `forge/sql/schema_bridge_process.dart` does.
const List<String> kDeployBridgeScriptPathSegments = <String>['deploy', 'deploy_bridge.ts'];

/// The `@Deploy` declaration read by importing [source] under [runtime], resolved against
/// [resolution].
///
/// Throws a [ToolExit] when the bridge leaves with a failure — two `Service` calls naming the same
/// service is the case this is written for, and its message is [runtime]'s own, relayed as it
/// printed it.
Future<DeclaredDeploy> runDeployBridge({
  required File source,
  required Resolution resolution,
  required JsRuntime runtime,
}) async {
  final File bridge = globals.templatePaths
      .root(globals.fs)
      .childDirectory(kScriptsDirectoryName)
      .childDirectory(kDeployBridgeScriptPathSegments[0])
      .childFile(kDeployBridgeScriptPathSegments[1]);

  if (!bridge.existsSync()) {
    throwToolExit(
      '${bridge.path} is missing. This tool ships it next to its binary, so an installation that '
      'never unpacked $kScriptsDirectoryName/${kDeployBridgeScriptPathSegments.join('/')} cannot render deploy/ '
      'from deploy.ts.',
    );
  }

  final ShellResult output = await runtime.runScript(
    bridge.path,
    scriptArgs: <String>[source.path],
    imports: resolution.imports,
  );

  if (output.error.isNotEmpty) globals.logger.printWarning(output.error);

  if (output.failed) {
    throwToolExit('the deploy bridge failed under ${runtime.name}, exit code ${output.exitCode}.');
  }

  return DeclaredDeploy.fromJson(jsonDecode(output.stdout) as Map<String, dynamic>);
}
