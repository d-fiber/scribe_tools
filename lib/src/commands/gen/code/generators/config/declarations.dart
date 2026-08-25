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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/config/declaration_scan.dart';
import 'package:scribe_tools/src/commands/gen/routes/emitter.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Writes the functions the host loads a project's own declarations through.
///
/// The framework used to import four fixed paths under `lib/extensions/`, which
/// made the framework the one deciding where a project keeps its own code. It now
/// imports this file, and the paths in it come from a scan: a declaration goes
/// wherever its author wants it, under whatever name, and is declared nowhere.
///
/// Which kinds exist is not written down here either. A package says in its
/// manifest which buckets it opens, so mounting a package is what gives a project
/// a kind to declare, and neither the framework nor this tool names a package.
///
/// The buckets stay apart because the host loads each at a different moment.
/// Merging them would pull every declaration into the earliest one, and loading a
/// module costs enough here for that to be felt.
Future<void> generateDeclarations() async {
  final List<DeclaredKind> kinds = mountedKinds();
  final Map<DeclaredKind, List<String>> found = DeclarationScanner.discover(kinds);

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.declarations.writeAsString(renderDeclarations(found));

  globals.logger.printStatus(
    '${found.values.fold<int>(0, (int total, List<String> files) => total + files.length)} declaration(s) '
    'in ${kinds.length} bucket(s), written to '
    '${globals.project.generatedDirectoryName}/sdk/js/declarations.ts',
  );
}

/// The whole generated module, one exported function per bucket of [found].
///
/// A bucket with nothing found still gets its function, answering an empty list:
/// a project that declares no cron is a normal project, not a broken one, and the
/// package that opened the bucket is mounted either way.
///
/// A project that mounts no package opening a bucket gets a file with no function
/// at all. Nothing then asks it for one, since it is a mounted package that makes
/// the host call for a kind.
String renderDeclarations(Map<DeclaredKind, List<String>> found) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('// This file is auto-generated do not edit manually.')
    ..writeln('// Run: $kToolName gen code');

  for (final MapEntry<DeclaredKind, List<String>> entry in found.entries) {
    final String imports = entry.value.map((String file) => 'import("${specifierOf(file)}")').join(', ');

    buffer
      ..writeln()
      ..writeln(
        '/** Loads every "${entry.key.marker}" of "${entry.key.package}" this project declared, '
        'wherever it put them. */',
      )
      ..writeln('export function ${entry.key.bucket}(): Promise<unknown[]> {')
      ..writeln('  return Promise.all([$imports]);')
      ..writeln('}');
  }

  return buffer.toString();
}
