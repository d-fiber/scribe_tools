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
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/layout.dart';

/// The export a package's entry carries when it lets a project declare something against it.
///
/// The key is the name of the generated loader function; the value is the symbol a project file
/// imports from the package's door to declare one. It lives in code rather than in the manifest
/// because the value is a class the entry already has in scope:
///
/// ```ts
/// export const declares = { queues: Queue, crons: Cron };
/// ```
///
/// A package that lets a project declare nothing leaves the export out.
const String kDeclaresExport = 'declares';

/// What a bucket name and a marker have to look like to be written into TypeScript.
///
/// A bucket becomes the name of an exported function and a marker is compared to an imported name,
/// so neither can be anything a source file could not spell.
final RegExp _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

final RegExp _declaresBlock = RegExp('export\\s+const\\s+$kDeclaresExport\\s*=\\s*\\{([^}]*)\\}');

/// The buckets [source] opens, bucket to the marker it names, empty when it opens none.
///
/// [where] names the file in whatever is thrown. Throws a [ToolExit] when a `$kDeclaresExport`
/// export is there but cannot be read: a pair that is not `bucket: Marker`, a bucket or a marker
/// that is not an identifier, or a bucket opened twice.
Map<String, String> declaresIn(String source, String where) {
  final RegExpMatch? match = _declaresBlock.firstMatch(source);
  if (match == null) return const <String, String>{};

  final Map<String, String> found = <String, String>{};
  for (final String pair in match.group(1)!.split(',')) {
    if (pair.trim().isEmpty) continue;

    final List<String> sides = pair.split(':');
    if (sides.length != 2) {
      throwToolExit('$where: "$kDeclaresExport" holds "${pair.trim()}", which is not "bucket: Marker".');
    }

    final String bucket = sides[0].trim();
    final String marker = sides[1].trim();
    if (!_identifier.hasMatch(bucket) || !_identifier.hasMatch(marker)) {
      throwToolExit(
        '$where: "$kDeclaresExport" holds "${pair.trim()}", which is not a name a source file could spell.',
      );
    }
    if (found.containsKey(bucket)) {
      throwToolExit('$where: "$kDeclaresExport" opens "$bucket" twice.');
    }

    found[bucket] = marker;
  }

  return found;
}

/// The buckets the package at [directory], called [name], opens through its entry.
///
/// Reads the fixed path [entryOf] names. A package with no entry, which `layoutProblems` already
/// refuses on its own, opens nothing rather than failing a second time here.
Map<String, String> readDeclares(String directory, String name) {
  final File entry = globals.fs.file(p.join(directory, entryOf(name)));
  if (!entry.existsSync()) return const <String, String>{};
  return declaresIn(entry.readAsStringSync(), entry.path);
}
