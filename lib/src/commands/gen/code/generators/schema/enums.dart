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

import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/emit/project_enums.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/enum_scan.dart';
import 'package:scribe_tools/src/commands/gen/sql_scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Rewrites the project's `enums.ts`, and names what it declared.
///
/// The returned names are what the table generator routes its imports with: an
/// enum is declared by the framework or by the project, never by both, so a
/// name that is missing from this set comes from the SDK.
///
/// The framework's own enums are only read. Their TypeScript ships with the
/// framework, so nothing is written for them here.
Future<Set<String>> generateEnums() async {
  final List<ParsedEnum> fromFramework = await scanEnums(kernelSqlRoots());
  globals.logger.printStatus('${fromFramework.length} kernel enums read from the SDK');

  final List<ParsedEnum> fromProject = await scanEnums(<Directory>[globals.project.init]);
  if (fromProject.isEmpty) return <String>{};

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.enums.writeAsString(renderProjectEnums(fromProject).join('\n'));

  globals.logger.printStatus(
    '${fromProject.length} project enums, written to '
    '${globals.project.generatedDirectoryName}/sdk/js/enums.ts',
  );

  return <String>{for (final ParsedEnum parsed in fromProject) parsed.name.toPascalCase()};
}
