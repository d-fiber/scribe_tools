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

/// The directory, inside a package, holding the TypeScript its SQL schema is declared in.
///
/// It sits beside [kProtocolDirectory] rather than under [kDeployDirectory]: both are codegen
/// sources rather than something a running stack reads directly, and `scribe forge` compiles this
/// one into `deploy/$kDatabaseDirectory/init/$kGeneratedSchemaFile` the same way `protoc` compiles
/// [kProtocolDirectory] into a stub.
const String kSchemaDirectory = 'schema';

/// The file `scribe forge` writes a package's declared schema into.
///
/// It is rebuilt whole on every forge, never patched, so its content only ever answers for what
/// `schema/` currently declares. A package that hand-writes its SQL instead carries no `schema/`
/// and never gets this file.
const String kGeneratedSchemaFile = '00_schema.sql';

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

/// The fragments a service directory cannot leave out.
///
/// `docker-compose.yaml` is the service itself, `capacity.yaml` is what a
/// deployment sizes it by; neither has a default a directory could fall back
/// to, unlike the five that stay conditional.
const List<String> kMandatoryServiceFragments = <String>['capacity.yaml', 'docker-compose.yaml'];

/// The file a resource type says what every recipe for it has to return in.
///
/// It sits beside a recipe rather than inside one, and it is what tells [deployProblems] a
/// `deploy/recipes/<type>/` directory is not empty by accident: `deploy/resources.dart` reads the
/// same file for the contract it enforces at deploy time.
const String kRecipeContract = 'contract.yaml';

/// The file a package writes `deploy/deploy.ts` under, the sole source `scribe forge` reads when
/// it renders the rest of `deploy/` from a package's `@Deploy` declaration.
///
/// Its presence is what tells [deployProblems] the generated entries of [kDeployEntries] —
/// `services/`, `recipes/`, `overlay.yaml`, `configuration.yaml`, `packages.env` — are owned by
/// `scribe forge` rather than by hand: a package that carries it is checked for drift the same way
/// `scribe_packages`' own CI already checks `package.lock`, by running `scribe forge` again and
/// diffing what it wrote, not by a second rule here. A package without it keeps writing every one
/// of those entries by hand, exactly as before.
const String kDeployDeclarationFile = 'deploy.ts';

/// What may sit directly under `deploy/`, and nothing else may.
///
/// `db` is the only one a package cannot omit. `services/` holds one directory per service,
/// `recipes/` one per resource type, and the four files are read where they sit: `deploy.ts` is
/// the source a package's `@Deploy` declares against, `overlay.yaml` mounts `deploy/db/` into a
/// base service, `configuration.yaml` names what a project tunes and requires, `packages.env` is
/// the package's own slice of the environment.
const List<String> kDeployEntries = <String>[
  kDatabaseDirectory,
  kServicesDirectory,
  kRecipesDirectory,
  kDeployDeclarationFile,
  'overlay.yaml',
  'configuration.yaml',
  'packages.env',
];

/// The suffix of a file the stub generator compiles.
const String kProtocolSuffix = '.proto';

/// The suffix of a file the schema bridge compiles.
const String kSchemaSuffix = '.ts';

/// The suffix of a file the database plays.
const String kSqlSuffix = '.sql';

/// What is wrong with what the package at [directory] hands the stack, empty when nothing is.
///
/// Three directories are read here, `deploy/` and the two siblings `protocol/` and `schema/`,
/// because all three stand in for a declaration nobody writes: what they contain **is** what the
/// package hands over, so a stray file where the tree does not expect one, or an optional
/// directory carrying nothing of the kind it promises, is the only way any of this can be wrong.
List<String> deployProblems(String directory) {
  final List<String> problems = <String>[
    ..._deployTreeProblems(directory),
    ..._protocolProblems(directory),
    ..._schemaProblems(directory),
  ];
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

  final bool hasDeployTs = deploy.childFile(kDeployDeclarationFile).existsSync();
  final List<String> problems = <String>[
    ..._strayEntries(deploy, kDeployEntries, kDeployDirectory),
    ..._generatedEntriesProblems(deploy, hasDeployTs: hasDeployTs),
  ];

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
      final String name = p.basename(service.path);
      problems.addAll(
        hasDeployTs
            ? _generatedServiceFragmentProblems(service, name)
            : _missingMandatoryFragmentProblems(service, name),
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

/// The entries of `deploy/` a `deploy/deploy.ts` renders at deploy time and never writes to disk,
/// which may never sit directly under `deploy/` at all once one exists: found there, they can
/// only be a leftover from before a package adopted `deploy.ts`, or from a `deploy.ts` line
/// removed since.
///
/// `deploy/services/` is not one of them, even though `deploy.ts` renders what it carries too: a
/// service directory may still hold a `Dockerfile` a `Build` source names, which is nobody's but
/// its author's and belongs nowhere else — see [_generatedServiceFragmentProblems], the narrower
/// check that applies to it instead.
const List<String> kGeneratedOnlyDeployEntries = <String>[
  kRecipesDirectory,
  'overlay.yaml',
  'configuration.yaml',
  'packages.env',
];

/// Problems naming an entry of [kGeneratedOnlyDeployEntries] that sits in [deploy] alongside a
/// `deploy.ts`, when [hasDeployTs].
///
/// `scribe run`/`scribe deploy` render every one of these into a throwaway copy under the
/// project's own generated directory, never into the package itself — see `ops/deploy_render.dart`
/// — so nothing legitimately writes them here once `deploy.ts` exists, and one found on disk is
/// dead weight from before the package carried it, or from a `deploy.ts` line since removed.
List<String> _generatedEntriesProblems(Directory deploy, {required bool hasDeployTs}) {
  if (!hasDeployTs) return const <String>[];

  return <String>[
    for (final String name in kGeneratedOnlyDeployEntries)
      if (deploy.childDirectory(name).existsSync() || deploy.childFile(name).existsSync()) _generatedEntryProblem(name),
  ];
}

String _generatedEntryProblem(String name) =>
    'it carries $kDeployDirectory/$name alongside $kDeployDirectory/$kDeployDeclarationFile, which renders it at '
    'deploy time and never writes it to disk. Remove it: nothing here reads it any more.';

/// Problems naming a [kServiceFragments] entry found in [service], a `deploy/services/<name>/`
/// beside a `deploy.ts`.
///
/// Unlike [kGeneratedOnlyDeployEntries], the directory itself is not refused: it may still carry a
/// `Dockerfile` a `Build` source names, or a script a fragment's own path reaches. Only the seven
/// fragment names the framework owns are, since `deploy.ts` is what renders every one of them now.
List<String> _generatedServiceFragmentProblems(Directory service, String name) => <String>[
  for (final String fragment in kServiceFragments)
    if (service.childFile(fragment).existsSync()) _generatedServiceFragmentProblem(name, fragment),
];

String _generatedServiceFragmentProblem(String name, String fragment) =>
    'its $kDeployDirectory/$kServicesDirectory/$name/$fragment sits alongside $kDeployDirectory/'
    '$kDeployDeclarationFile, which renders it at deploy time and never writes it to disk. Remove it: nothing '
    'here reads it any more.';

/// Problems naming a [kMandatoryServiceFragments] entry missing from [service], a hand-written
/// `deploy/services/<name>/`.
List<String> _missingMandatoryFragmentProblems(Directory service, String name) => <String>[
  for (final String fragment in kMandatoryServiceFragments)
    if (!service.childFile(fragment).existsSync())
      'its $kDeployDirectory/$kServicesDirectory/$name/ has no $fragment, which every service carries.',
];

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

List<String> _schemaProblems(String directory) {
  final Directory schema = globals.fs.directory(p.join(directory, kSchemaDirectory));
  if (!schema.existsSync()) return const <String>[];
  if (_holdsA(schema, (String name) => name.endsWith(kSchemaSuffix))) return const <String>[];

  const String problem =
      'its $kSchemaDirectory/ holds no $kSchemaSuffix file, so the directory says its SQL is '
      'generated and nothing declares any.';
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
