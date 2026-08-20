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
import 'dart:io';

import 'package:fiber_shell/fiber_shell.dart';
import 'package:path/path.dart' as p;

import 'generated_path.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/base/common.dart';

Future<GeneratedPathsDocument> runWalker(Directory root, String surface) async {
  final Directory walkerDir = Directory(p.join(root.path, 'scribe/tools/docs'));

  final ShellResult result = await Deno.run()
      .allowRead()
      .allowEnv()
      .allowSys()
      .allowNet()
      .file('walk_routes.ts')
      .scriptArg('--surface=$surface')
      .scriptArg('--root=${root.path}')
      .output(cwd: walkerDir.path);

  if (result.error.isNotEmpty) globals.logger.printWarning(result.error);

  if (result.failed) {
    throwToolExit('deno walker failed ($surface), exit code ${result.exitCode}');
  }

  return GeneratedPathsDocument.fromJson(jsonDecode(result.stdout) as Map<String, dynamic>);
}

void validateTags(GeneratedPathsDocument doc, Set<String> knownTags) {
  for (final GeneratedPathEntry entry in doc.paths) {
    if (!knownTags.contains(entry.tag)) {
      throwToolExit(
        '${doc.surface}: path "${entry.path}" uses unknown tag "${entry.tag}" '
        '(not among ${knownTags.join(', ')})',
      );
    }
  }
}
