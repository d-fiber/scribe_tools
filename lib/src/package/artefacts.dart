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

import 'package:path/path.dart' as p;

import 'package:scribe_tools/src/base/common.dart';

/// The key, at the root of a manifest, holding what the package hands the stack.
///
/// It sits under a name of its own rather than at the root because what it holds
/// is read by the framework and by nothing else, the way `flutter:` is in a
/// pubspec. A package that hands the stack nothing leaves the block out.
const String kArtefactsKey = 'scribe';

/// The keys the artefacts block may carry, and no others.
const List<String> kArtefactsKeys = <String>['db', 'protocol', 'ops'];

/// The names a fragment of the ops templates goes by, and the whole of them.
///
/// A fragment's name is what pairs it with the file of the base it completes, and
/// there is no table relating the two. The list belongs to the framework, and the
/// other copy is in `lib/src/ops/`, so a package never repeats it and never
/// invents one: a file under another name is reached through a path written
/// inside a fragment, and nothing looks it up.
const List<String> kOpsFragments = <String>[
  'capacity.yaml',
  'docker-compose.yaml',
  'kong.yml',
  'overlay.yaml',
  'replicas.yaml',
  'resources.yaml',
  'tuning.yaml',
];

/// The suffix of a file the database plays.
const String kSqlSuffix = '.sql';

/// The suffix of a file the stub generator compiles.
const String kProtocolSuffix = '.proto';

/// The keys the `db:` block may carry, one per moment Postgres plays SQL at.
const List<String> kDatabaseKeys = <String>['init', 'migrations', 'provisioning'];

/// The SQL a package poses, one directory per moment it is played at.
///
/// A block with nothing under it is no block at all, the way an empty
/// `dependencies:` is, so what reaches [Artefacts.db] is either a block that
/// named a directory or null.
///
/// Each directory is harvested whole, subdirectories included, and the files are
/// played in the order their paths sort in. That is what a numeric prefix on a
/// directory is for, and why nothing here declares an order of its own.
class Database {
  /// Holds the three directories a `db:` block named, null for each it left out.
  const Database({required this.init, required this.migrations, required this.provisioning});

  /// The SQL played once, when the database container is built, or null.
  final String? init;

  /// The SQL played at every start, one pass per file the migrator has not seen, or null.
  final String? migrations;

  /// The SQL played before anything else, the roles, extensions and schemas, or null.
  final String? provisioning;

  /// Whether the block named no directory at all.
  bool get isEmpty => init == null && migrations == null && provisioning == null;

  /// Every directory this block named, from the key that named it.
  Map<String, String> get declared => <String, String>{
    'init': ?init,
    'migrations': ?migrations,
    'provisioning': ?provisioning,
  };
}

/// What a package hands the stack besides the code the host imports.
///
/// Nothing here is derived from the tree. The keys are the framework's and the
/// list is closed; the paths are the package's, which names its directories what
/// it likes and puts them where it likes inside itself. A directory the manifest
/// does not name is a directory nothing plays, mounts or compiles, which is what
/// makes leaving the block out the way to hand over nothing.
class Artefacts {
  /// Holds what an artefacts block named, empty for each part it left out.
  const Artefacts({required this.db, required this.protocol, required this.ops});

  /// What a manifest with no artefacts block declares, which is nothing.
  static const Artefacts none = Artefacts(db: null, protocol: null, ops: <String>[]);

  /// The SQL this package poses, or null when it poses none.
  final Database? db;

  /// The directory holding the `.proto` files, or null when it speaks to no worker.
  ///
  /// Its path decides the path of the generated stubs, since `protoc` is handed
  /// the root of the repository and resolves everything against it.
  final String? protocol;

  /// The ops directories this package contributes, one per service, in the order written.
  ///
  /// An entry is a directory, and what it hands over is the fragments it holds:
  /// `docker-compose.yaml`, `capacity.yaml`, `resources.yaml`, `tuning.yaml`,
  /// `replicas.yaml`, `overlay.yaml`. That list belongs to the framework and a
  /// package never repeats it, because a fragment's name is what pairs it with
  /// the template it completes.
  ///
  /// Everything else a service needs, a Dockerfile or a script, is reached
  /// through a path written inside a fragment, so nothing looks it up by name and
  /// nothing has to declare it. An entry may also be a single fragment, for a
  /// package whose ops are a handful of files rather than a service of its own.
  final List<String> ops;

  /// Whether the block named nothing at all.
  bool get isEmpty => (db == null || db!.isEmpty) && protocol == null && ops.isEmpty;

  /// Every path this block named, from the key that named it.
  ///
  /// It is what the checks walk: the manifest says a path is there, and only the
  /// tree says whether it is.
  Map<String, String> get declared => <String, String>{
    for (final MapEntry<String, String> entry in db?.declared.entries ?? const <MapEntry<String, String>>[])
      '$kArtefactsKey.db.${entry.key}': entry.value,
    '$kArtefactsKey.protocol': ?protocol,
    for (int index = 0; index < ops.length; index++) '$kArtefactsKey.ops[$index]': ops[index],
  };

  /// The artefacts [value] spells, where [value] is what `scribe:` held in [where].
  ///
  /// Throws a [ToolExit] when the block is not a mapping, when it carries a key
  /// that means nothing, or when a path reaches outside the package.
  factory Artefacts.parse(Object? value, String where) {
    if (value == null) return none;
    if (value is! Map) {
      throwToolExit('$where holds "$kArtefactsKey:" as something other than a block of paths.');
    }

    for (final Object? key in value.keys) {
      if (kArtefactsKeys.contains(key)) continue;
      throwToolExit(
        '$where holds "$kArtefactsKey.$key:", which means nothing. The block holds '
        '${kArtefactsKeys.join(', ')}, and a package that hands over none of them leaves it out.',
      );
    }

    return Artefacts(
      db: _database(value['db'], where),
      protocol: value.containsKey('protocol') ? _path(value['protocol'], '$kArtefactsKey.protocol', where) : null,
      ops: _ops(value['ops'], where),
    );
  }
}

Database? _database(Object? value, String where) {
  if (value == null) return null;
  if (value is! Map) {
    throwToolExit('$where holds "$kArtefactsKey.db:" as something other than a block of paths.');
  }

  for (final Object? key in value.keys) {
    if (kDatabaseKeys.contains(key)) continue;
    throwToolExit(
      '$where holds "$kArtefactsKey.db.$key:", which means nothing. Postgres plays SQL at three '
      'moments, and the block names them: ${kDatabaseKeys.join(', ')}.',
    );
  }

  final Database read = Database(
    init: value.containsKey('init') ? _path(value['init'], '$kArtefactsKey.db.init', where) : null,
    migrations: value.containsKey('migrations')
        ? _path(value['migrations'], '$kArtefactsKey.db.migrations', where)
        : null,
    provisioning: value.containsKey('provisioning')
        ? _path(value['provisioning'], '$kArtefactsKey.db.provisioning', where)
        : null,
  );

  return read.isEmpty ? null : read;
}

List<String> _ops(Object? value, String where) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throwToolExit(
      '$where holds "$kArtefactsKey.ops:" as something other than a list. One entry per service, '
      "each the directory holding that service's fragments.",
    );
  }
  final List<String> found = <String>[];
  for (int index = 0; index < value.length; index++) {
    final String written = _path(value[index], '$kArtefactsKey.ops[$index]', where);
    if (found.contains(written)) {
      throwToolExit('$where names "$written" twice under "$kArtefactsKey.ops:".');
    }
    found.add(written);
  }

  return found;
}

String _path(Object? value, String key, String where) {
  if (value is! String || value.isEmpty) {
    throwToolExit('$where holds "$key:" as something other than a path.');
  }

  if (p.posix.isAbsolute(value)) {
    throwToolExit(
      '$where holds "$key: $value", which is an absolute path. A package names what it carries, '
      'relative to itself, so that it says the same thing wherever it is checked out.',
    );
  }

  final String normalised = p.posix.normalize(value);
  if (normalised == '..' || normalised.startsWith('../')) {
    throwToolExit(
      '$where holds "$key: $value", which climbs out of the package. What a package hands over is '
      'what it carries, and reaching next door would hand over something it does not own.',
    );
  }

  return normalised == '.' ? '.' : normalised;
}
