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

import 'package:scribe_tools/src/commands/gen/code/generators/config/import_map.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Writes the project's two import maps.
///
/// This is the dependency inversion that lets the framework be moved. The
/// framework's own configuration used to point at `../../lib/`, so it had to be
/// the project's sibling; now the project points at the framework, absolutely,
/// and the framework no longer has to know a project exists.
///
/// There are two files because the engine's paths do not exist inside the
/// container. `scribe.json` is what the editor and a local check read;
/// `scribe.container.json` is mounted and passed as `--config` by the compose.
///
/// Neither name says which runtime is underneath: nothing on the project's side
/// should give away what the framework is implemented with.
Future<void> generateScribeConfig() async {
  final Map<String, dynamic> frameworkConfig =
      jsonDecode(await globals.project.sdk.denoJson.readAsString()) as Map<String, dynamic>;
  final Map<String, String> inherited = inheritedImports(frameworkConfig);

  await globals.project.generated.sdk.create();

  await globals.project.generated.sdk.importMap.writeAsString(
    renderImportMap(
      frameworkConfig,
      inherited,
      frameworkRoot: asDirectory(globals.project.sdk.path),
      projectRoot: asDirectory(globals.project.lib.path),
      assetsRoot: asDirectory(globals.project.assets.path),
    ),
  );

  await globals.project.generated.sdk.containerImportMap.writeAsString(
    renderImportMap(
      frameworkConfig,
      inherited,
      frameworkRoot: '/app/scribe/',
      projectRoot: '/app/lib/',
      assetsRoot: '/app/assets/',
    ),
  );

  globals.logger.printStatus(
    '${inherited.length} deps inherited, written to '
    '${globals.project.generatedDirectoryName}/sdk/js/scribe{,.container}.json',
  );
}
