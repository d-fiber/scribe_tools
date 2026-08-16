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

import 'dart:convert';

import 'package:scribe/src/commands/gen/code/generators/config/import_map.dart';
import 'package:scribe/src/globals.dart' as globals;

/// Writes the project's two import maps.
///
/// This is the dependency inversion that lets the framework be moved. The
/// framework's own configuration used to point at `../../lib/`, so it had to be
/// the project's sibling; now the project points at the framework, absolutely,
/// and the framework no longer has to know a project exists.
///
/// There are two files because the host's paths do not exist inside the
/// container. `scribe.json` is what the editor and a local check read;
/// `scribe.container.json` is mounted and passed as `--config` by the compose.
///
/// Neither name says which runtime is underneath: nothing on the project's side
/// should give away what the framework is implemented with.
Future<void> generateScribeConfig() async {
  final Map<String, dynamic> frameworkConfig =
      jsonDecode(await globals.project.sdk.hostDenoJson.readAsString()) as Map<String, dynamic>;
  final Map<String, String> inherited = inheritedImports(frameworkConfig);

  await globals.project.generated.sdk.create();

  await globals.project.generated.sdk.importMap.writeAsString(
    renderImportMap(
      frameworkConfig,
      inherited,
      frameworkRoot: asDirectory(globals.project.sdk.host.path),
      projectRoot: asDirectory(globals.project.lib.path),
      assetsRoot: asDirectory(globals.project.assets.path),
    ),
  );

  await globals.project.generated.sdk.containerImportMap.writeAsString(
    renderImportMap(
      frameworkConfig,
      inherited,
      frameworkRoot: '/app/scribe/host/',
      projectRoot: '/app/lib/',
      assetsRoot: '/app/assets/',
    ),
  );

  globals.logger.printStatus(
    '${inherited.length} deps inherited → ${globals.project.generatedDirectoryName}/sdk/js/scribe{,.container}.json',
  );
}
