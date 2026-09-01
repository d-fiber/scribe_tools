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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/checks.dart';
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/dependency_source.dart';
import 'package:scribe_tools/src/package/imports.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/lock.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';

/// The specifier the language is imported under.
const String kLanguage = '@scribe/alchemy';

/// The directory a package keeps what was resolved for it in.
const String kResolutionDirectory = '.scribe';

/// The file holding what resolving decided, in our own words.
///
/// It is ours and it is the only thing in [kResolutionDirectory] that is: the
/// checkout that resolved, the package it resolved, and what each specifier the
/// package may write answers to. Nothing in it is shaped for a runtime.
///
/// A package author never opens it and never commits it, because it holds paths
/// that are true on one machine and false on the next.
const String kResolutionFile = 'resolution.json';

/// The file a package freezes what resolving found for its dependencies into.
///
/// Unlike [kResolutionFile] it is committed: it names versions, never a path, so
/// what it says stays true on a machine that never ran the resolution that wrote
/// it. See [PackageLock].
const String kPackageLockFile = 'package.lock';

/// What a package needs from outside itself, beyond the language and the test harness.
///
/// Empty today. A package's test harness is `@scribe/alchemy/test`, reached the same way
/// as the language: through [frameworkImports], which reads it straight out of the
/// checkout's own map rather than pinning a version here. There is nothing left that a
/// package needs and the checkout would not already publish.
const Map<String, String> kAlwaysResolved = <String, String>{};

/// The directory, inside a checkout, holding the packages it carries.
const String kPackagesDirectory = 'packages';

/// The specifiers a package named [name] at [directory] is reached through.
///
/// A package opens one door per file sitting directly in `lib/`: `@scribe/<name>`
/// for the entry, and `@scribe/<name>/<subject>` for every other `lib/<subject>.ts`.
/// The list is read off that directory, not a manifest, the same way `deploy/` is:
/// a package carries no `deno.json` to name its doors in, and a tool that made the
/// list up instead once handed a caller only the entry, so every subject door of a
/// dependency went unresolved and nothing that imported one could be type checked.
///
/// Three doors the layout fixes are added on top: the test harness, its settings,
/// and the end-to-end stack, that last one only when the package's e2e is a Deno
/// suite rather than a shell scenario.
///
/// The one door never handed to a dependent is `@scribe/<name>/`, which opens
/// every file under the package. [own] is true only for the package being
/// resolved, which reaches its own files through it.
Map<String, String> _doorsOf(String name, String directory, {required bool own}) {
  final Map<String, String> doors = <String, String>{};

  void open(String specifier, String at) => doors[specifier] = Uri.file(p.absolute(at)).toString();

  open('@scribe/$name', p.join(directory, entryOf(name)));

  final Directory library = globals.fs.directory(p.join(directory, kLibraryDirectory));
  if (library.existsSync()) {
    final List<FileSystemEntity> held = library.listSync()
      ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));
    for (final FileSystemEntity entity in held) {
      if (entity is! File || !entity.path.endsWith('.ts')) continue;

      final String subject = p.basenameWithoutExtension(entity.path);
      if (subject != name) open('@scribe/$name/$subject', entity.path);
    }
  }

  open('@scribe/$name/testing', p.join(directory, kHarnessEntry));
  open('@scribe/$name/testing/settings', p.join(directory, kHarnessSettings));

  // Only a package whose e2e is a Deno suite publishes this door. One whose
  // `tests/e2e/` is a shell scenario has no `stack.ts` to point at.
  if (globals.fs.file(p.join(directory, kE2eStack)).existsSync()) {
    open('@scribe/$name/e2e', p.join(directory, kE2eStack));
  }

  if (own) doors['@scribe/$name/'] = Uri.directory(p.absolute(directory)).toString();

  return doors;
}

/// What a package asked for and could not be given, in the sentence a caller prints.
class Unresolved {
  /// Records that [name] could not be answered, for [reason].
  const Unresolved(this.name, this.reason);

  /// The name the manifest wrote.
  final String name;

  /// Why nothing could be put behind it.
  final String reason;

  @override
  String toString() => '"$name": $reason';
}

/// Where a package called [name] is, or null when nowhere holds one.
///
/// Two places are tried, in this order: beside [directory], which is the workspace
/// the package being resolved is written in, and the checkout's own
/// [kPackagesDirectory]. The neighbour comes first so that two packages edited
/// together see each other's working tree rather than the copy a checkout was last
/// given, which is what a workspace is for.
///
/// A directory whose manifest calls itself something else is not a match. The name
/// a package is reached under is the one it declares, and answering the directory
/// would put a package behind a specifier that names another.
String? directoryOfPackage(String name, String directory, Sdk sdk) {
  final List<String> tried = <String>[
    p.join(p.dirname(p.absolute(directory)), name),
    p.join(sdk.root, kPackagesDirectory, name),
  ];

  for (final String held in tried) {
    final File manifest = globals.fs.file(p.join(held, kManifestFile));
    if (!manifest.existsSync()) continue;
    if (Manifest.parse(manifest.readAsStringSync(), manifest.path).name != name) continue;

    return held;
  }

  return null;
}

/// Where [_resolveDependency] found a dependency, and what a lock writes about it.
class _ResolvedDependency {
  const _ResolvedDependency({required this.directory, required this.source, this.gitCommit});

  /// The directory holding the dependency's own `package.yaml`.
  final String directory;

  /// Where it was found, as [PackageLock] names it.
  final LockSource source;

  /// The commit `git` checked out, set only when [source] is [LockSource.git].
  final String? gitCommit;
}

/// Where a dependency called [name], written as [source] in the manifest at
/// [directory], is found, or null when nothing answers for it.
///
/// A [SdkSource] is searched for at [directoryOfPackage]'s own two places.
/// A [PathSource] is resolved against [directory] itself, the manifest that
/// wrote it: `package.yaml` writes a path relative to the package, never to a
/// project the way `config.yaml` does. A [GitSource] is resolved by
/// [resolveGit], against the cache every git dependency shares.
///
/// A directory whose manifest calls itself something else is not a match,
/// whichever kind of source found it: the name a package is reached under is
/// the one it declares.
_ResolvedDependency? _resolveDependency(String name, DependencySource source, String directory, Sdk sdk) {
  switch (source) {
    case SdkSource():
      final String? at = directoryOfPackage(name, directory, sdk);
      if (at == null) return null;
      return _ResolvedDependency(directory: at, source: _hostedSourceOf(at, sdk));

    case PathSource(:final String path):
      final String at = p.normalize(p.join(directory, path));
      if (!_namesItself(at, name)) return null;
      return _ResolvedDependency(directory: at, source: LockSource.path);

    case GitSource():
      final (Directory found, String commit) = resolveGit(
        name,
        source,
        where: '"$name" in ${p.join(directory, kManifestFile)}',
      );
      if (!_namesItself(found.path, name)) return null;
      return _ResolvedDependency(directory: found.path, source: LockSource.git, gitCommit: commit);
  }
}

/// Whether the manifest at [at] calls itself [name].
bool _namesItself(String at, String name) {
  final File manifest = globals.fs.file(p.join(at, kManifestFile));
  if (!manifest.existsSync()) return false;

  return Manifest.parse(manifest.readAsStringSync(), manifest.path).name == name;
}

/// Where [directoryOfPackage] found a [SdkSource] dependency living at [at].
///
/// The two places it ever looks are its own: beside the package being
/// resolved, or the checkout's [kPackagesDirectory]. Telling them apart is a
/// path comparison and nothing more, because that is all it itself decided
/// between.
LockSource _hostedSourceOf(String at, Sdk sdk) =>
    p.equals(p.dirname(p.absolute(at)), p.join(sdk.root, kPackagesDirectory)) ? LockSource.sdk : LockSource.workspace;

/// What [asker] gets refused for, having asked for [name] as [source] and found nothing.
String _unresolvedReason(String name, DependencySource source, Manifest asker, String directory, Sdk sdk) =>
    switch (source) {
      SdkSource() =>
        '${asker.name} depends on it, and no package of that name sits beside '
            '${p.dirname(directory)} or in ${p.join(sdk.root, kPackagesDirectory)}.',
      PathSource(:final String path) =>
        '${asker.name} depends on it at path: "$path", and ${p.normalize(p.join(directory, path))} '
            'does not hold a package called "$name".',
      GitSource(:final String url) =>
        '${asker.name} depends on it from git: "$url", and what was checked out does not hold '
            'a package called "$name".',
    };

/// Every package [manifest] reaches, its dependencies' own dependencies included.
///
/// The walk is breadth first over what each manifest declares, and a name already
/// answered is not walked twice, so a diamond costs one visit and a cycle
/// terminates. What comes back is keyed by name because that is what a specifier
/// carries; two directories claiming one name is a problem [problems] reports
/// rather than a pick this makes quietly.
///
/// What a manifest's dev dependencies hold is walked for the package being resolved
/// and for nothing else. A consumer does not run somebody else's suite, so what
/// that suite needed stops at the package that wrote it. The same line separates
/// [external]: `lib/` is scanned for every package the walk meets, since a file of a
/// dependency is compiled with the package that reached it, while `tests/` is
/// scanned for the package being resolved alone.
///
/// [external] comes back holding every specifier that scan met, outside the
/// framework and outside a package, which is everything left once both of those
/// are read off the manifests instead. Nothing here is declared: it is read
/// straight from the code that imports it, in [externalSpecifiersIn].
///
/// [manifests], when given, is filled with the manifest the walk read at each
/// path in the result, keyed the same way. [locked], when given, is filled with
/// what a lock writes about the same dependency: where [_resolveDependency]
/// found it, and the commit it checked out when that was a [GitSource]. Both
/// exist so a caller that needs either, [PackageLock] does, reads it off the
/// walk instead of resolving or parsing a second time.
///
/// A git dependency that `git` itself cannot clone, fetch or check out throws
/// straight out of [resolveGit] rather than joining [problems]: that is an
/// infrastructure failure, not a manifest asking for something that does not
/// exist, and batching it with the rest would let a package with both kinds of
/// trouble hide the first behind whichever the walk happens to meet second.
Map<String, String> packageClosure(
  Manifest manifest,
  String directory,
  Sdk sdk,
  Set<String> external,
  List<Unresolved> problems, {
  Map<String, Manifest>? manifests,
  Map<String, LockedPackage>? locked,
}) {
  final Map<String, String> found = <String, String>{};
  final List<MapEntry<Manifest, String>> pending = <MapEntry<Manifest, String>>[
    MapEntry<Manifest, String>(manifest, p.absolute(directory)),
  ];

  bool first = true;
  while (pending.isNotEmpty) {
    final MapEntry<Manifest, String> held = pending.removeAt(0);
    external.addAll(externalSpecifiersIn(p.join(held.value, kLibraryDirectory)));
    if (first) {
      external.addAll(externalSpecifiersIn(p.join(held.value, kTestsDirectory)));
    }

    final Map<String, DependencySource> asked = <String, DependencySource>{
      ...held.key.dependencies,
      if (first) ...held.key.devDependencies,
    };
    first = false;

    asked.forEach((String name, DependencySource source) {
      if (found.containsKey(name) || name == manifest.name) return;

      final _ResolvedDependency? resolved = _resolveDependency(name, source, held.value, sdk);
      if (resolved == null) {
        problems.add(Unresolved(name, _unresolvedReason(name, source, held.key, held.value, sdk)));
        return;
      }

      final Manifest reached = loadManifest(resolved.directory);
      if (source is SdkSource && !allows(source.constraint, reached.version)) {
        problems.add(
          Unresolved(
            name,
            '${held.key.name} accepts ${source.constraint}, and the copy at ${resolved.directory} '
            'publishes ${reached.version}.',
          ),
        );
        return;
      }

      found[name] = resolved.directory;
      manifests?[name] = reached;
      locked?[name] = LockedPackage(
        name: name,
        version: reached.version,
        source: resolved.source,
        resolvedRef: resolved.gitCommit,
      );
      pending.add(MapEntry<Manifest, String>(reached, resolved.directory));
    });
  }

  return found;
}

/// What every specifier of [asked] answers to, taken from what the checkout pins.
///
/// A package never writes a version for one of these, so this is a lookup and not a
/// solve: the checkout's map is the one place a version of anything outside the
/// framework is decided, and a second one written anywhere else would be a second
/// place for the two to disagree.
///
/// An entry may answer to an exact key or to the longest prefix of [pinned] that
/// ends in `/` and that the specifier starts with, the way an import map itself
/// resolves a path under a scope it was only given the root of: `@scope/pkg/deep`
/// is carried by an entry written `@scope/pkg/`, and what lands in the result is
/// that entry, not the deeper specifier nobody pinned on its own.
///
/// A specifier the checkout does not pin, by either name, is reported rather than
/// dropped. Dropping it would leave the package to fail at type check, where
/// nothing points back at the line that asked for it.
Map<String, String> externalImports(Set<String> asked, Sdk sdk, Map<String, String> pinned, List<Unresolved> problems) {
  final Map<String, String> imports = <String, String>{};

  for (final String specifier in asked) {
    final String? exact = pinned[specifier];
    if (exact != null) {
      imports[specifier] = exact;
      continue;
    }

    final String? prefix = _longestPrefix(specifier, pinned.keys);
    if (prefix != null) {
      imports[prefix] = pinned[prefix]!;
      continue;
    }

    problems.add(
      Unresolved(
        specifier,
        'nothing in ${p.join(sdk.root, kSdkImportMapFile)} answers it, so the checkout does not carry it. '
        'Add it there first, where its version is pinned for everybody.',
      ),
    );
  }

  return imports;
}

/// The longest key of [candidates] ending in `/` that [specifier] starts with, or null.
///
/// Longest wins because a narrower scope pinned on purpose says more than a wider
/// one that happens to also match: `@scope/pkg/sub/` beats `@scope/pkg/` for a
/// specifier both would carry.
String? _longestPrefix(String specifier, Iterable<String> candidates) {
  String? found;
  for (final String candidate in candidates) {
    if (!candidate.endsWith('/') || !specifier.startsWith(candidate)) continue;
    if (found == null || candidate.length > found.length) found = candidate;
  }
  return found;
}

/// What resolving a package left behind.
class Resolution {
  /// Records that [directory] was resolved against [sdk], writing [imports].
  const Resolution({required this.directory, required this.sdk, required this.imports});

  /// The path of the directory the resolution was written into.
  final String directory;

  /// The checkout it was resolved against.
  final Sdk sdk;

  /// What each specifier the package may write now answers to.
  final Map<String, String> imports;

  /// The path of the file holding what was decided, in our own words.
  String get file => p.join(directory, kResolutionDirectory, kResolutionFile);

  /// [imports], in the one shape `deno` itself reads: a `data:` URL a `--import-map`
  /// flag takes directly, so nothing ever has to be written to disk for `deno` to
  /// see what we decided. No file, so no path true on one machine and false on the
  /// next, and no `.gitignore` entry to keep pointed at it.
  String get importMap {
    final String json = jsonEncode(<String, Object>{'imports': imports});
    return 'data:application/json;base64,${base64Encode(utf8.encode(json))}';
  }

  /// The path of the file freezing the versions this resolution found, committed.
  String get lockFile => p.join(directory, kPackageLockFile);
}

/// Whether [package] has a resolution that was written against [sdk].
///
/// Answers false when nothing was resolved, when what was resolved names another
/// version, and when the file cannot be read at all. All three are the same thing
/// to a caller: it has to resolve again before it can do anything.
bool isResolved(String package, Sdk sdk) {
  final File written = globals.fs.file(p.join(package, kResolutionDirectory, kResolutionFile));
  if (!written.existsSync()) return false;

  try {
    final Object? document = jsonDecode(written.readAsStringSync());
    if (document is! Map<String, Object?>) return false;

    final Object? checkout = document[kEnvironmentKey];
    return checkout is Map<String, Object?> && checkout['version'] == sdk.version;
  } on FormatException {
    return false;
  }
}

/// Stops the run when anything the package asked for could not be answered.
///
/// They are reported together rather than one at a time, because a package that
/// asks for three things the checkout does not carry is three lines to fix, and a
/// command that stops at the first turns one pass into three.
///
/// Nothing is written when this throws. A map missing what the package needed
/// would type check against whatever the last run left behind, and the run after
/// it would report a different set.
///
/// Throws a [ToolExit] when [problems] is not empty.

void _refuseUnresolved(List<Unresolved> problems, Manifest manifest, String directory) {
  if (problems.isEmpty) return;

  final StringBuffer said = StringBuffer(
    '${manifest.name} asks for ${problems.length == 1 ? 'something' : '${problems.length} things'} '
    'that cannot be resolved, so nothing was written.\n',
  );
  for (final Unresolved problem in problems) {
    said.writeln('  $problem');
  }
  said.write(
    'A package is named in ${p.join(directory, kManifestFile)}; a specifier the checkout does not '
    'pin is named wherever the code imports it.',
  );

  throwToolExit('$said');
}

/// Resolves the package in [directory] against [sdk], and answers what it left.
///
/// What the package reaches is what its manifest declares and nothing besides: the
/// language, the packages it depends on and theirs in turn, and the specifiers the
/// checkout pins that it asked for by name. A package that imports what it never
/// declared does not resolve, which is the point of reading the manifest at all.
///
/// The versions of everything outside the framework are the checkout's, so two
/// packages cannot disagree on which redis client they got, and a package written
/// outside a checkout reaches exactly what it would reach inside one.
///
/// The manifest is read for three reasons: it refuses a directory that is not a
/// package before anything is written, it gives the name the package reaches its
/// own files under, so that a file may cite a neighbour the way everything else
/// does rather than by counting directories, and it names the framework versions
/// the package accepts.
///
/// That last one is checked here and nowhere else, because this is the one place a
/// package and a checkout meet. A checkout the package refuses would otherwise
/// resolve, and the run would end in a hundred type errors that name files rather
/// than the version that caused them.
///
/// Throws a [ToolExit] when [directory] carries no manifest, when it carries one
/// that cannot be read, when the package fails its own checks, when [sdk] is not a
/// checkout the package accepts, and when anything it declared cannot be answered.
Resolution resolve(String directory, Sdk sdk) {
  final Manifest manifest = loadManifest(directory);
  _refuseBroken(manifest, directory);
  _refuseMismatch(manifest, sdk, directory);

  final List<Unresolved> problems = <Unresolved>[];
  final Map<String, String> pinned = sdkImports(sdk);
  final Set<String> external = <String>{};
  final Map<String, Manifest> manifests = <String, Manifest>{};
  final Map<String, LockedPackage> locked = <String, LockedPackage>{};
  final Map<String, String> reached = packageClosure(
    manifest,
    directory,
    sdk,
    external,
    problems,
    manifests: manifests,
    locked: locked,
  );

  final Map<String, String> imports = <String, String>{
    ...kAlwaysResolved,
    ...frameworkImports(sdk),
    ...externalImports(external, sdk, pinned, problems),
    for (final MapEntry<String, String> held in reached.entries) ..._doorsOf(held.key, held.value, own: false),
    ..._doorsOf(manifest.name, directory, own: true),
  };

  _refuseUnresolved(problems, manifest, directory);

  final Directory held = globals.fs.directory(p.join(directory, kResolutionDirectory))..createSync(recursive: true);

  _write(p.join(held.path, kResolutionFile), <String, Object>{
    'package': manifest.name,
    'entry': entryOf(manifest.name),
    kEnvironmentKey: <String, Object>{'root': p.absolute(sdk.root), 'version': sdk.version},
    'reaches': imports,
  });

  PackageLock(
    scribe: sdk.version,
    packages: locked.values.toList()..sort((LockedPackage a, LockedPackage b) => a.name.compareTo(b.name)),
  ).writeTo(globals.fs.file(p.join(directory, kPackageLockFile)));

  return Resolution(directory: p.absolute(directory), sdk: sdk, imports: imports);
}

void _write(String path, Map<String, Object> document) =>
    globals.fs.file(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(document)}\n');

/// Stops before writing anything when the package does not hold together.
///
/// Reading the manifest catches what the text gets wrong, a name, a version, a
/// path that climbs out of the package. It cannot catch what the text and the
/// tree disagree on, and that is most of it: a declared directory that is not
/// there, an ops entry that holds no fragment, a missing entry file. Left to the
/// resolution, all of those are written down as if they were true, and the
/// package is mounted somewhere before anybody finds out.
void _refuseBroken(Manifest manifest, String directory) {
  final List<Problem> problems = problemsWithin(
    DiscoveredPackage(manifest: manifest, directory: p.absolute(directory)),
  );
  if (problems.isEmpty) return;

  throwToolExit(
    '${manifest.name} does not hold together, so nothing was resolved:\n'
    '${problems.map((Problem problem) => '  ${problem.message}').join('\n')}',
  );
}

void _refuseMismatch(Manifest manifest, Sdk sdk, String directory) {
  if (allows(manifest.scribe, sdk.version)) return;

  throwToolExit(
    '${manifest.name} accepts scribe ${manifest.scribe}, and the checkout at ${sdk.root} '
    'publishes ${sdk.version}.\n'
    'Point $kSdkRootVariable at a checkout it accepts, or widen "environment.$kEnvironmentKey:" '
    'in ${p.join(directory, kManifestFile)} once you have run the suite against this one.',
  );
}

/// The specifiers a checkout publishes without any package having to ask for them.
///
/// The language, `@scribe/alchemy`, and the checkout's own door, `@scribe/sdk`, are neither
/// under [kLayersDirectory] nor a package, so nothing discovers them: they are named here and
/// nowhere else. Every layer [layerImports] finds joins them, which is what makes
/// `@scribe/contracts/`, `@scribe/runtime/` and the rest reachable the same way, without a
/// `dependencies:` entry that never had a version to carry in the first place.
const List<String> kFixedFrameworkImports = <String>[kLanguage, '@scribe/sdk'];

/// Every entry the framework publishes on its own, from the specifier to what it answers.
///
/// They are read out of the checkout's own map rather than a manifest of the framework's own,
/// because none of [kFixedFrameworkImports] or a layer carries one: each is a plain directory of
/// the tree, and the checkout is the one place that says what it publishes, which is also where
/// every other version is pinned.
///
/// Writing one entry of a surface and leaving the rest out is what once made six of the
/// language's seven unreachable, so a package that imported one of them failed to resolve while
/// the command line reported nothing. Every entry under a granted root is kept for that reason.
///
/// Throws a [ToolExit] when the checkout's map names no entry for the language, since that is the
/// one surface a package cannot be resolved without.
Map<String, String> frameworkImports(Sdk sdk) {
  final Map<String, String> held = sdkImports(sdk);
  final Set<String> roots = <String>{...kFixedFrameworkImports, ...layerImports(sdk).keys};

  final Map<String, String> imports = <String, String>{
    for (final MapEntry<String, String> entry in held.entries)
      if (roots.any((String root) => entry.key == root || entry.key.startsWith('$root/'))) entry.key: entry.value,
  };

  if (!imports.keys.any((String key) => key == kLanguage || key.startsWith('$kLanguage/'))) {
    throwToolExit(
      'The map at ${p.join(sdk.root, kSdkImportMapFile)} names no "$kLanguage", so the language cannot be resolved.\n'
      'A checkout publishes the language through its own import map, one entry per surface a package may import.',
    );
  }

  return imports;
}
