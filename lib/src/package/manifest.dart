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
import 'package:scribe_tools/src/package/artefacts.dart';
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/name.dart';
import 'package:yaml/yaml.dart';

/// What a package says about itself before anybody has written the sentence.
///
/// It reads as an instruction because that is what it is. A description nobody
/// replaced is a package nobody described, and a placeholder that says so is more
/// use than a plausible sentence that turns out to describe nothing.
const String kDefaultDescription = 'Say in one sentence what this package does.';

/// The keys a manifest may carry, and no others.
///
/// What a package is made of is read off its tree: the one way in is
/// `lib/<name>.ts` because a package has one, it is named after the package, and
/// a manifest able to point elsewhere would only be a chance for the two to
/// disagree. What it hands the stack is the other way round, and [kArtefactsKey]
/// is where it says so.
const List<String> kManifestKeys = <String>[
  'name',
  'description',
  'version',
  'environment',
  'dependencies',
  'dev_dependencies',
  kArtefactsKey,
];

/// The key holding what a package needs to run its own suite and nothing else.
const String kDevDependenciesKey = 'dev_dependencies';

/// The key, inside `environment:`, naming the framework a package is written against.
const String kEnvironmentKey = 'scribe';

/// What a package says about itself, and the whole of what its manifest holds.
class Manifest {
  /// Holds what a manifest said, with nothing filled in on its behalf.
  const Manifest({
    required this.name,
    required this.description,
    required this.version,
    required this.scribe,
    required this.dependencies,
    required this.devDependencies,
    required this.artefacts,
  });

  /// The name the package is mounted, imported and written into a project under.
  final String name;

  /// What the package is for, in one sentence.
  final String description;

  /// The version this copy of the package publishes.
  final String version;

  /// The framework versions this package accepts, as the constraint it wrote.
  ///
  /// It is what the package says it was written against, and it is checked before
  /// anything resolves. Without it a package would take whatever checkout is on
  /// hand and fail at type check, where nothing points back at the version.
  final String scribe;

  /// What this package may import, from a name to the constraint it accepts.
  ///
  /// Two kinds share the block, the way they do in a `pubspec.yaml`, and the
  /// constraint says which is which. A name carrying a version is another package,
  /// checked against the copy on hand. A name carrying [kAny] is a specifier the
  /// checkout pins, and the package names it without naming a version because the
  /// checkout is the one place a version of anything outside the framework lives.
  ///
  /// Nothing outside this block resolves. A package that imports what it did not
  /// declare fails to resolve, which is the whole reason the block is read at all.
  final Map<String, String> dependencies;

  /// What the package's own suite may import, on top of [dependencies].
  ///
  /// It does not travel: a package that depends on this one gets [dependencies]
  /// and never what was written here, because a consumer does not run somebody
  /// else's tests.
  final Map<String, String> devDependencies;

  /// What this package hands the stack: its SQL, its `.proto` files, its ops.
  ///
  /// A manifest with no [kArtefactsKey] block hands over nothing, and that is the
  /// whole of the rule. Nothing falls back on a conventional path, so a directory
  /// the manifest does not name is one nothing plays, mounts or compiles, and a
  /// package that needs none of it says so by leaving the block out.
  final Artefacts artefacts;

  /// The manifest [source] spells, where [source] is the text of a `package.yaml`.
  ///
  /// [where] is the path the text came from, named in whatever is thrown. Throws a
  /// [ToolExit] when the document is not a mapping, when a required key is missing,
  /// or when a key holds something other than what it is meant to.
  factory Manifest.parse(String source, String where) {
    final Object? document = _read(source, where);
    if (document is! Map) {
      throwToolExit('$where is not a mapping. It opens with "name:" and "version:".');
    }

    for (final Object? key in document.keys) {
      if (kManifestKeys.contains(key)) continue;
      throwToolExit(
        '$where carries "$key", which means nothing. A manifest holds ${kManifestKeys.join(', ')}, '
        'and the rest is read from the package itself.',
      );
    }

    final String name = _text(document, 'name', where);
    final String? problem = packageNameProblem(name);
    if (problem != null) throwToolExit('$where: $problem');

    return Manifest(
      name: name,
      description: _optionalText(document, 'description', where) ?? kDefaultDescription,
      version: _version(document, where),
      scribe: _environment(document, where),
      dependencies: _dependencies(document, 'dependencies', where),
      devDependencies: _dependencies(document, kDevDependenciesKey, where),
      artefacts: Artefacts.parse(document[kArtefactsKey], where),
    );
  }

  /// The manifest text a package called [name] carries when it is created,
  /// written against the framework [scribe] publishes.
  ///
  /// The constraint is a caret on the checkout that wrote it, so a package starts
  /// out accepting everything up to the next framework version allowed to break
  /// it. Narrowing that is the author's call, and widening it is a claim the
  /// author has to have tested.
  ///
  /// The `dependencies:` block is written even though it is empty. A package with
  /// nothing under it says so, rather than leaving a reader to wonder whether the
  /// key was forgotten, and the empty block reads the same as no block at all.
  ///
  /// The [kArtefactsKey] block is written commented out, which is the one place a
  /// manifest carries prose. A fresh package hands the stack nothing, and an empty
  /// block would be a claim it does; commented out, it says what the keys are and
  /// what the paths could be, for whoever comes to fill one in, the way a fresh
  /// pubspec does. Every line of it is in [_artefacts].
  static String skeleton(String name, String scribe) =>
      'name: $name\n'
      'description: $kDefaultDescription\n'
      'version: 1.0.0\n'
      '\n'
      'environment:\n'
      '  $kEnvironmentKey: "^$scribe"\n'
      '\n'
      'dependencies:\n'
      '\n'
      '$kDevDependenciesKey:\n'
      '\n'
      '$_artefacts';
}

const String _artefacts =
    """
# $kArtefactsKey:
#   # What a package hands the stack, and the only place it says so. Leave the
#   # block out and it hands over nothing: no path here falls back on a default.
#   #
#   # The keys are ours. The paths are yours: name the directories what you like
#   # and put them where you like inside the package. What follows is the layout
#   # most packages settle on, not a requirement.
#   #
#   # A path is a directory, harvested whole, subdirectories included. The files
#   # are played in the order their paths sort in, which is what a numeric prefix
#   # on a directory is for.
#   db:
#     # Played once, when the database container is built.
#     init: ./db/init/
#     # Played at every start, one pass per file the migrator has not seen.
#     migrations: ./db/migrations/
#     # Played before anything else: the roles, the extensions, the schemas.
#     provisioning: ./db/provisioning/
#   # The directory holding the .proto files this package speaks to a worker.
#   # protoc is handed the root of the repository, so this path decides where the
#   # generated stubs land.
#   protocol: ./protocol/
#   # One entry per service, each the directory holding that service's fragments:
#   # docker-compose.yaml, capacity.yaml, resources.yaml, tuning.yaml,
#   # replicas.yaml, overlay.yaml. Those names belong to the framework and a
#   # package never repeats them here, since a fragment's name is what pairs it
#   # with the template it completes. Everything else a service needs, a
#   # Dockerfile or a script, is reached through a path written inside a fragment,
#   # so its name is yours and nothing has to declare it.
#   ops:
#     - ./ops/database/
#     - ./ops/queue/
""";

final RegExp _release = RegExp(r'^\d+\.\d+\.\d+$');

Object? _read(String source, String where) {
  try {
    return loadYaml(source);
  } on YamlException catch (error) {
    throwToolExit('$where is not readable as YAML: ${error.message}');
  }
}

String _version(Map<Object?, Object?> document, String where) {
  final String written = _text(document, 'version', where);
  if (!_release.hasMatch(written)) {
    throwToolExit('$where holds "version: $written", which is not a version. Write three numbers, as in "1.0.2".');
  }
  return written;
}

String _environment(Map<Object?, Object?> document, String where) {
  final Object? value = document['environment'];
  if (value == null) {
    throwToolExit(
      '$where has no "environment:". A package names the framework it was written against, '
      'so that a checkout it cannot run on is refused before anything is resolved:\n'
      '\n'
      'environment:\n'
      '  $kEnvironmentKey: "^1.0.0"',
    );
  }
  if (value is! Map) {
    throwToolExit('$where holds "environment:" as something other than a block of names and versions.');
  }

  for (final Object? key in value.keys) {
    if (key == kEnvironmentKey) continue;
    throwToolExit(
      '$where holds "environment.$key:", which means nothing. The block names "$kEnvironmentKey:" '
      'and nothing else.',
    );
  }

  final Object? asked = value[kEnvironmentKey];
  if (asked == null) throwToolExit('$where has no "environment.$kEnvironmentKey:".');
  if (asked is! String) {
    throwToolExit('$where holds "environment.$kEnvironmentKey:" as something other than a word.');
  }

  final String? problem = constraintProblem(asked);
  if (problem != null) throwToolExit('$where: $problem');

  return asked;
}

String _text(Map<Object?, Object?> document, String key, String where) {
  final String? value = _optionalText(document, key, where);
  if (value == null) throwToolExit('$where has no "$key:".');
  return value;
}

String? _optionalText(Map<Object?, Object?> document, String key, String where) {
  final Object? value = document[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;

  if (value is String) {
    throwToolExit(
      '$where holds "$key:" with nothing after it but space. A key that has nothing to say is left '
      'out, rather than written empty.',
    );
  }

  if (value is num) {
    throwToolExit(
      '$where holds "$key: $value", which YAML reads as a number rather than as text. Three numbers '
      'separated by dots are text on their own, as in "1.0.0"; anything shorter has to be quoted.',
    );
  }

  throwToolExit('$where holds "$key:" as something other than a word.');
}

/// The block at [key], read as a name against the constraint it accepts.
///
/// A name is only held to the rules of a package name when it carries a version,
/// because that is the entry that names a package. An entry written [kAny] names a
/// specifier the checkout pins, and a specifier is whatever an import map may
/// hold: a scope, a slash, a registry prefix. Refusing those here would mean a
/// package could not declare the redis client it plainly imports.
Map<String, String> _dependencies(Map<Object?, Object?> document, String key, String where) {
  final Object? value = document[key];
  if (value == null) return const <String, String>{};
  if (value is! Map) {
    throwToolExit('$where holds "$key:" as something other than a block of names and versions.');
  }

  final Map<String, String> asked = <String, String>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? constraint = entry.value;
    if (constraint is! String) {
      throwToolExit('$where holds "$key.${entry.key}:" as something other than a word.');
    }

    final String name = '${entry.key}';
    final String? written = constraintProblem(constraint);
    if (written != null) throwToolExit('$where, at "$key.$name:": $written');

    if (constraint != kAny) {
      final String? named = packageNameProblem(name);
      if (named != null) throwToolExit('$where, at "$key.$name:": $named');
    }

    asked[name] = constraint;
  }

  return asked;
}
