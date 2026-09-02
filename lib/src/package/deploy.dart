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
import 'package:scribe_tools/src/globals.dart' as globals;

/// The directory every package carries, holding everything a running stack reads.
///
/// Its shape is fixed and closed, which is what lets a manifest declare none of it: the SQL, the
/// compose fragments, the recipes and the configuration each sit at a place [deployProblems] knows
/// by name, so a reader finds them by walking the tree instead of looking a path up in
/// `package.yaml`. A package that hands the stack nothing still carries an empty
/// `deploy/db/init/` and `deploy/db/migrations/`.
const String kDeployDirectory = 'deploy';

/// The subdirectory of [kDeployDirectory] holding a package's SQL.
const String kDatabaseDirectory = 'db';

/// The subdirectory of [kDeployDirectory] holding one directory per service the package starts.
const String kServicesDirectory = 'services';

/// The subdirectory of [kDeployDirectory] holding one directory per resource type it answers.
const String kRecipesDirectory = 'recipes';

/// The directory, inside a package, holding its `.proto` contract.
const String kProtocolDirectory = 'protocol';

/// The moments Postgres plays a package's SQL at, one directory each under `deploy/db/`.
///
/// A directory is harvested whole, subdirectories included, and the files are played in the order
/// their paths sort in. That is what a numeric prefix on a file or a directory is for.
const List<String> kDatabaseMoments = <String>['init', 'migrations', 'provisioning'];

/// The moments a package cannot leave out: the container build, and every start after it.
const List<String> kRequiredDatabaseMoments = <String>['init', 'migrations'];

/// The names a service fragment goes by, and the whole of them.
///
/// A fragment's name is what pairs it with the file of the base it completes, and there is no table
/// relating the two. The list belongs to the framework, and the other copy is in
/// `alchemy/package/deploy.ts`, so a package never repeats it and never invents one: a file under
/// another name is reached through a path written inside a fragment, and nothing looks it up.
const List<String> kServiceFragments = <String>[
  'capacity.yaml',
  'docker-compose.yaml',
  'kong.yml',
  'overlay.yaml',
  'replicas.yaml',
  'resources.yaml',
  'tuning.yaml',
];

/// The file a resource type says what every recipe for it has to return in.
///
/// It sits beside a recipe rather than inside one, and it is what tells [deployProblems] a
/// `deploy/recipes/<type>/` directory is not empty by accident: `deploy/resources.dart` reads the
/// same file for the contract it enforces at deploy time.
const String kRecipeContract = 'contract.yaml';

/// What may sit directly under `deploy/`, and nothing else may.
///
/// `db` is the only one a package cannot omit. `services/` holds one directory per service,
/// `recipes/` one per resource type, and the three files are read where they sit: `overlay.yaml`
/// mounts `deploy/db/` into a base service, `configuration.yaml` names what a project tunes and
/// requires, `packages.env` is the package's own slice of the environment.
const List<String> kDeployEntries = <String>[
  kDatabaseDirectory,
  kServicesDirectory,
  kRecipesDirectory,
  'overlay.yaml',
  'configuration.yaml',
  'packages.env',
];

/// The suffix of a file the stub generator compiles.
const String kProtocolSuffix = '.proto';

/// The suffix of a file the database plays.
const String kSqlSuffix = '.sql';

/// What is wrong with what the package at [directory] hands the stack, empty when nothing is.
///
/// Two directories are read here, `deploy/` and the sibling `protocol/`, because both stand in for
/// a declaration nobody writes: what they contain **is** what the package hands over, so a stray
/// file where the tree does not expect one, or an optional directory carrying nothing of the kind
/// it promises, is the only way any of this can be wrong.
List<String> deployProblems(String directory) {
  final List<String> problems = <String>[..._deployTreeProblems(directory), ..._protocolProblems(directory)];
  return problems;
}

List<String> _deployTreeProblems(String directory) {
  final Directory deploy = globals.fs.directory(p.join(directory, kDeployDirectory));
  if (!deploy.existsSync()) {
    final String problem =
        'it has no $kDeployDirectory/, which is where a running stack reads everything a package '
        'hands it, starting with $kDeployDirectory/$kDatabaseDirectory/${kRequiredDatabaseMoments.first}/.';
    return <String>[problem];
  }

  final List<String> problems = <String>[..._strayEntries(deploy, kDeployEntries, kDeployDirectory)];

  final Directory database = deploy.childDirectory(kDatabaseDirectory);
  if (!database.existsSync()) {
    problems.add('it has no $kDeployDirectory/$kDatabaseDirectory/, which every package carries.');
  } else {
    problems.addAll(_strayEntries(database, kDatabaseMoments, '$kDeployDirectory/$kDatabaseDirectory'));
    for (final String moment in kRequiredDatabaseMoments) {
      if (!database.childDirectory(moment).existsSync()) {
        problems.add('it has no $kDeployDirectory/$kDatabaseDirectory/$moment/.');
      }
    }
    for (final String moment in kDatabaseMoments) {
      if (kRequiredDatabaseMoments.contains(moment)) continue;
      problems.addAll(
        _emptyOptionalDirectory(database.childDirectory(moment), '$kDeployDirectory/$kDatabaseDirectory/$moment'),
      );
    }
  }

  final Directory services = deploy.childDirectory(kServicesDirectory);
  problems.addAll(_emptyOptionalDirectory(services, '$kDeployDirectory/$kServicesDirectory'));
  if (services.existsSync()) {
    for (final Directory service in services.listSync(followLinks: false).whereType<Directory>()) {
      if (_holdsA(service, kServiceFragments.contains)) continue;
      problems.add(
        'its $kDeployDirectory/$kServicesDirectory/${p.basename(service.path)}/ holds no fragment. A '
        "service is recognised by the files that carry a base's own name: ${kServiceFragments.join(', ')}.",
      );
    }
  }

  final Directory recipes = deploy.childDirectory(kRecipesDirectory);
  problems.addAll(_emptyOptionalDirectory(recipes, '$kDeployDirectory/$kRecipesDirectory'));
  if (recipes.existsSync()) {
    for (final Directory recipe in recipes.listSync(followLinks: false).whereType<Directory>()) {
      if (recipe.childFile(kRecipeContract).existsSync()) continue;
      problems.add(
        'its $kDeployDirectory/$kRecipesDirectory/${p.basename(recipe.path)}/ has no $kRecipeContract, '
        'which every recipe directory carries beside the recipe that answers it.',
      );
    }
  }

  return problems;
}

/// A problem naming [directory] at [label], when it exists but holds nothing.
///
/// An optional directory says something by existing at all: `deploy/recipes/`
/// present says this package owns a resource type, `deploy/services/` present
/// says it carries a container. Left empty, it keeps saying that with nothing
/// behind it, which is indistinguishable from a directory nobody finished.
List<String> _emptyOptionalDirectory(Directory directory, String label) {
  if (!directory.existsSync() || directory.listSync(followLinks: false).isNotEmpty) return const <String>[];

  return <String>['its $label/ is there and empty, which says this package needs it and carries nothing of it.'];
}

List<String> _protocolProblems(String directory) {
  final Directory protocol = globals.fs.directory(p.join(directory, kProtocolDirectory));
  if (!protocol.existsSync()) return const <String>[];
  if (_holdsA(protocol, (String name) => name.endsWith(kProtocolSuffix))) return const <String>[];

  const String problem =
      'its $kProtocolDirectory/ holds no $kProtocolSuffix file, so the directory says it speaks to a '
      'worker and nothing does.';
  return <String>[problem];
}

List<String> _strayEntries(Directory directory, List<String> known, String label) {
  final List<String> problems = <String>[];
  for (final FileSystemEntity entry in directory.listSync(followLinks: false)) {
    final String name = p.basename(entry.path);
    if (known.contains(name)) continue;
    problems.add('its $label/ carries "$name", which means nothing there. It holds ${known.join(', ')}.');
  }
  return problems;
}

bool _holdsA(Directory directory, bool Function(String name) wanted) {
  for (final FileSystemEntity entry in directory.listSync(followLinks: false)) {
    if (entry is File && wanted(p.basename(entry.path))) return true;
    if (entry is Directory && _holdsA(entry, wanted)) return true;
  }
  return false;
}
