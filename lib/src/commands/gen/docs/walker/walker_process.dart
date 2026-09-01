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
import 'dart:io';

import 'package:fiber_shell/fiber_shell.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The routes of [surface], read by running the Deno walker that ships with the framework at [root].
///
/// Throws a [ToolExit] when the walker leaves with a failure, since a partial
/// read would be written out as a document missing routes.
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
    throwToolExit('Deno walker failed ($surface), exit code ${result.exitCode}.');
  }

  return GeneratedPathsDocument.fromJson(jsonDecode(result.stdout) as Map<String, dynamic>);
}

/// Refuses [doc] when one of its routes is filed under a tag outside [knownTags].
///
/// Throws a [ToolExit] naming the route and the tag. A tag nobody declared
/// produces a section no reader can reach, and OpenAPI does not complain.
void validateTags(GeneratedPathsDocument doc, Set<String> knownTags) {
  for (final GeneratedPathEntry entry in doc.paths) {
    if (!knownTags.contains(entry.tag)) {
      throwToolExit(
        '${doc.surface}: path "${entry.path}" uses unknown tag "${entry.tag}" '
        '(not among ${knownTags.join(', ')}).',
      );
    }
  }
}
