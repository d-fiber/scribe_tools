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

import 'package:scribe_tools/src/dependencies.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Every directory of socle SQL, in the order it has to be applied.
///
/// The socle comes first, the mounted modules next, sorted so the order does
/// not depend on the file system, and the migrations last.
List<Directory> kernelSqlRoots() => <Directory>[
  globals.project.sdk.dbInit,
  ..._moduleSqlRoots(),
  globals.project.sdk.dbMigrations,
];

List<Directory> _moduleSqlRoots() {
  final List<Directory> roots = <Directory>[
    for (final Dependency dependency in Dependencies.load().active)
      if (dependency.sql case final Directory sql) sql,
  ]..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return roots;
}

/// Calls [visit] on every `.sql` under [dir], however deep.
///
/// A directory that is not there is walked as an empty one, since a module may
/// ship no SQL at all.
Future<void> walkSqlFiles(Directory dir, Future<void> Function(File file) visit) async {
  if (!dir.existsSync()) return;
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    if (entity is Directory) {
      await walkSqlFiles(entity, visit);
    } else if (entity is File && entity.path.endsWith('.sql')) {
      await visit(entity);
    }
  }
}
