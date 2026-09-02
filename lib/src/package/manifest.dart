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
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/dependency_source.dart';
import 'package:scribe_tools/src/package/name.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';
import 'package:yaml/yaml.dart';

/// What a package says about itself before anybody has written the sentence.
///
/// It reads as an instruction because that is what it is. A description nobody
/// replaced is a package nobody described, and a placeholder that says so is more
/// use than a plausible sentence that turns out to describe nothing.
const String kDefaultDescription = 'Say in one sentence what this package does.';

/// The keys a manifest may carry, and no others.
///
/// What a package is made of, and what it hands the stack, are both read off its tree: the one way
/// in is `lib/<name>.ts` because a package has one and it is named after the package, and what it
/// hands over sits at the fixed places `deploy/` and `protocol/` name. A manifest able to point
/// elsewhere would only be a chance for the two to disagree.
const List<String> kManifestKeys = <String>[
  'name',
  'description',
  'version',
  'environment',
  'dependencies',
  'dev_dependencies',
];

/// The key holding what a package needs to run its own suite and nothing else.
const String kDevDependenciesKey = 'dev_dependencies';

/// The key, inside `environment:`, naming the framework a package is written against.
const String kEnvironmentKey = 'scribe';

/// The key, inside `environment:`, naming the JS runtime a package's own tooling runs its
/// TypeScript on: its suite, and `schema/` when it has one.
const String kRuntimeEnvironmentKey = 'runtime';

/// What a package says about itself, and the whole of what its manifest holds.
class Manifest {
  /// Holds what a manifest said, with nothing filled in on its behalf.
  const Manifest({
    required this.name,
    required this.description,
    required this.version,
    required this.scribe,
    required this.runtime,
    required this.dependencies,
    required this.devDependencies,
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

  /// The JS runtime this package's own tooling runs its TypeScript on: `deno` or `bun`.
  ///
  /// `deno` when `environment.runtime:` names none, which is what every package written before
  /// this key existed already runs on.
  final String runtime;

  /// The packages this one may import, from a name to where it comes from.
  ///
  /// Every entry names another package, the way it does in a `pubspec.yaml`: nothing else has a
  /// place here. A name written against a plain constraint is a [SdkSource], resolved beside
  /// the package or under the checkout's own `packages/` the way it always was; one written
  /// against `path:` or `git:` is a [PathSource] or a [GitSource], read from wherever that names
  /// instead. What a package imports beyond the framework and beyond another package is not
  /// declared at all, it is read off the code that imports it, the way `deno` itself would read
  /// it, in `packageClosure`.
  final Map<String, DependencySource> dependencies;

  /// What the package's own suite may import, on top of [dependencies].
  ///
  /// It does not travel: a package that depends on this one gets [dependencies]
  /// and never what was written here, because a consumer does not run somebody
  /// else's tests.
  final Map<String, DependencySource> devDependencies;

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

    final String description = _optionalText(document, 'description', where) ?? kDefaultDescription;
    final String version = _version(document, where);
    final (String scribe, String runtime) = _environment(document, where);

    return Manifest(
      name: name,
      description: description,
      version: version,
      scribe: scribe,
      runtime: runtime,
      dependencies: _dependencies(document, 'dependencies', where),
      devDependencies: _dependencies(document, kDevDependenciesKey, where),
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
  /// What the package hands the stack is not part of this text at all: `createPackage`
  /// scaffolds the fixed `deploy/` tree beside it, empty, and a package fills it in by
  /// adding files rather than by writing a path.
}

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

(String scribe, String runtime) _environment(Map<Object?, Object?> document, String where) {
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
    if (key == kEnvironmentKey || key == kRuntimeEnvironmentKey) continue;
    throwToolExit(
      '$where holds "environment.$key:", which means nothing. The block names "$kEnvironmentKey:" '
      'and "$kRuntimeEnvironmentKey:".',
    );
  }

  final Object? asked = value[kEnvironmentKey];
  if (asked == null) throwToolExit('$where has no "environment.$kEnvironmentKey:".');
  if (asked is! String) {
    throwToolExit('$where holds "environment.$kEnvironmentKey:" as something other than a word.');
  }

  final String? problem = constraintProblem(asked);
  if (problem != null) throwToolExit('$where: $problem');

  return (asked, _runtime(value, where));
}

String _runtime(Map<Object?, Object?> environment, String where) {
  final Object? asked = environment[kRuntimeEnvironmentKey];
  if (asked == null) return JsRuntime.deno.name;

  final Iterable<String> known = JsRuntime.values.map((JsRuntime runtime) => runtime.name);
  if (asked is! String || !known.contains(asked)) {
    throwToolExit(
      '$where holds "environment.$kRuntimeEnvironmentKey: $asked", which is not a runtime this tool '
      'knows. Write one of: ${known.join(', ')}.',
    );
  }

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

/// The block at [key], read as a name against where it comes from.
///
/// Every name is held to the rules a package name follows, whatever it is written against: an
/// entry here always names a package, checked against the copy on hand, and a specifier that is
/// not one, a redis client, a scope, a registry prefix, is refused the same way a misspelt name
/// is. What a package imports beyond another package is not declared, it is read off the code.
Map<String, DependencySource> _dependencies(Map<Object?, Object?> document, String key, String where) {
  final Object? value = document[key];
  if (value == null) return const <String, DependencySource>{};
  if (value is! Map) {
    throwToolExit('$where holds "$key:" as something other than a block of names and versions.');
  }

  final Map<String, DependencySource> asked = <String, DependencySource>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final String name = '${entry.key}';
    final String? named = packageNameProblem(name);
    if (named != null) throwToolExit('$where, at "$key.$name:": $named');

    asked[name] = _dependencySource(entry.value, key: key, name: name, where: where);
  }

  return asked;
}

/// The source [value] spells for the dependency [name] holds under [key].
///
/// A plain word is a constraint, checked and stored as a [SdkSource]. A block carrying exactly
/// one of `path:` or `git:` is a [PathSource] or a [GitSource]; anything else, both at once
/// included, is refused.
DependencySource _dependencySource(Object? value, {required String key, required String name, required String where}) {
  if (value is String) {
    final String? problem = constraintProblem(value);
    if (problem != null) throwToolExit('$where, at "$key.$name:": $problem');
    return SdkSource(value);
  }

  if (value is! Map) {
    throwToolExit('$where holds "$key.$name:" as something other than a version, a path, or a git repository.');
  }

  final Object? path = value['path'];
  final Object? git = value['git'];
  final Iterable<String> unknown = value.keys
      .map((Object? entryKey) => entryKey.toString())
      .where((String entryKey) => entryKey != 'path' && entryKey != 'git');

  if (unknown.isNotEmpty) {
    throwToolExit('$where, at "$key.$name:": carries ${unknown.join(', ')}, which is not read.');
  }
  if (path != null && git != null) {
    throwToolExit(
      '$where, at "$key.$name:": is given both a path: and a git:, so where it comes from '
      'depends on which one is read first.',
    );
  }

  if (path != null) {
    if (path is! String || path.trim().isEmpty) {
      throwToolExit('$where, at "$key.$name.path:": holds something other than a word.');
    }
    return PathSource(path);
  }

  if (git != null) return _gitSource(git, key: key, name: name, where: where);

  throwToolExit('$where, at "$key.$name:": names neither a version, a path:, nor a git:.');
}

/// The [GitSource] the block under `git:` spells, for the dependency [name] holds under [key].
GitSource _gitSource(Object? value, {required String key, required String name, required String where}) {
  if (value is! Map) {
    throwToolExit('$where, at "$key.$name.git:": holds something other than url, ref and path.');
  }

  final Iterable<String> unknown = value.keys
      .map((Object? entryKey) => entryKey.toString())
      .where((String entryKey) => entryKey != 'url' && entryKey != 'ref' && entryKey != 'path');
  if (unknown.isNotEmpty) {
    throwToolExit('$where, at "$key.$name.git:": carries ${unknown.join(', ')}, which is not read.');
  }

  final Object? url = value['url'];
  if (url is! String || url.trim().isEmpty) {
    throwToolExit('$where, at "$key.$name.git:": has no "url:".');
  }

  final Object? ref = value['ref'];
  if (ref != null && (ref is! String || ref.trim().isEmpty)) {
    throwToolExit('$where, at "$key.$name.git.ref:": holds something other than a word.');
  }

  final Object? path = value['path'];
  if (path != null && (path is! String || path.trim().isEmpty)) {
    throwToolExit('$where, at "$key.$name.git.path:": holds something other than a word.');
  }

  return GitSource(url: url, ref: ref as String?, path: path as String?);
}
