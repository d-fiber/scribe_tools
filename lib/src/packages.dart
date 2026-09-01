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
import 'package:scribe_tools/src/ops/fragments.dart';
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/dependency_source.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/lock.dart';
import 'package:scribe_tools/src/package/manifest.dart';

/// The directory, inside a package, holding everything the stack reads.
///
/// The SQL, the compose fragments, the recipes and the configuration all sit
/// under it, and nothing the stack consumes sits anywhere else. `protocol/` is
/// not one of them: a `.proto` is compiled at build, not read by a running
/// stack.
const String deployDirectory = 'deploy';

/// The subdirectory of [deployDirectory] holding one directory per service.
const String servicesDirectory = 'services';

/// The subdirectory of [deployDirectory] holding a package's SQL.
const String sqlDirectory = 'db';

/// The subdirectory of `deploy/db/` played when the stack is built.
///
/// A package's `deploy/db/` also holds `migrations/` and `provisioning/`, which
/// are played by other hands and at another moment.
const String sqlInitDirectory = 'init';

/// The directory, inside a package, holding its contract.
const String protocolDirectory = 'protocol';

/// The file a package writes to hand the framework what it provides.
const String registrationFile = 'register.ts';

/// The file a package declares its name and its exports in.
const String packageFile = 'deno.json';

/// The template a package declares its services in, and the profiles they sit behind.
const String composeTemplate = 'docker-compose.yaml';

/// What a directory has to carry to be a package.
///
/// These are the four things the tools read from a package, and a directory
/// that carries none of them holds nothing a project could mount. Nothing is
/// declared anywhere: a package is recognised by what it is made of, so there
/// is no second place where the list of packages could disagree with the tree.
const Set<String> packageArtefacts = <String>{deployDirectory, protocolDirectory, registrationFile, packageFile};

/// The one package a project gets whether or not it names it.
///
/// It is not a preference: the framework does not compile without it. Every
/// other package is mounted when `config.yaml` asks for it by name, and never
/// otherwise.
const String foundationName = 'foundation';

/// The file a project freezes what it mounts, and what those in turn depend on, into.
///
/// It sits at the project's own root, beside `config.yaml`, and it is committed:
/// see [PackageLock].
const String kProjectLockFile = 'scribe.lock';

/// One mountable package, recognised by the artefacts its directory carries.
class Package {
  /// Holds the package called [name], living in [directory].
  const Package({required this.name, required this.directory});

  /// The package's name, which is the name of its directory: `foundation`.
  ///
  /// One segment and never two: the packages sit side by side under a single
  /// root, so a name is all there is to address one by, and it is what
  /// `config.yaml` writes.
  final String name;

  /// The directory the package lives in.
  final Directory directory;

  /// The SQL this package adds to the database, null when it ships none.
  Directory? get sql {
    final Directory found = directory
        .childDirectory(deployDirectory)
        .childDirectory(sqlDirectory)
        .childDirectory(sqlInitDirectory);
    return found.existsSync() ? found : null;
  }

  /// The Compose profiles this package's services sit behind.
  ///
  /// Read from the fragments rather than declared next to them: the `profiles:`
  /// key of a service is what Compose obeys, so a second copy would be the one
  /// that drifts, and it would drift towards giving a share of the machine to a
  /// container nothing ever starts.
  Set<String> get profiles => <String>{
    for (final File fragment in fragments(composeTemplate)) ..._profilesIn(fragment.readAsStringSync()),
  };

  /// The files this package's slices of [template] would be read from.
  ///
  /// Two places carry one: `deploy/<template>` for what the package hands over
  /// as a whole, `overlay.yaml` and its `packages.env` slice, and
  /// `deploy/services/<service>/<template>` for a service's own fragments. None
  /// is required to exist: a package contributes to the templates it has
  /// something to say about and to no others.
  List<File> fragments(String template) {
    final Directory deploy = directory.childDirectory(deployDirectory);
    if (!deploy.existsSync()) return const <File>[];

    final List<File> found = <File>[deploy.childFile(template)];
    final Directory services = deploy.childDirectory(servicesDirectory);
    if (services.existsSync()) {
      for (final Directory service in services.listSync().whereType<Directory>()) {
        found.add(service.childFile(template));
      }
    }

    return found.where((File file) => file.existsSync()).toList()..sort((File a, File b) => a.path.compareTo(b.path));
  }

  /// This package's slices of [template], one per subject that declares one.
  List<YamlFragment> fragmentsFor(String template) => <YamlFragment>[
    for (final File file in fragments(template)) YamlFragment(_labelOf(file), file.readAsStringSync()),
  ];

  /// The name written into the merged document above a fragment's block.
  ///
  /// A fragment that sits in a service directory names the service too, so a
  /// reader of the generated compose can tell `foundation/valkery` from
  /// `foundation/queue`. A service directory called like the package, the usual
  /// case for a package with one service, is written as the package alone.
  String _labelOf(File file) {
    final String subject = p.basename(file.parent.path);
    if (subject == deployDirectory || subject == name) return name;
    return '$name/$subject';
  }
}

/// Every package found under the packages root.
class Packages {
  /// Holds [all] the packages one walk found, and where each of them came from.
  const Packages(this.all, this._locations);

  /// Every package found, sorted by [Package.name].
  final List<Package> all;

  /// Where [load] found each package in [all], and the commit it checked out
  /// when that was a git dependency.
  ///
  /// It is kept from the moment a package is found rather than redecided from
  /// its directory afterwards, the same way `resolution.dart` keeps it: a git
  /// dependency's directory sits under the tool's cache, which is neither the
  /// checkout's `packages/` nor a `path:`, and nothing about it says so on its
  /// own.
  final Map<String, (LockSource, String?)> _locations;

  /// Every package directly under [root], the project's vendored `packages/`.
  ///
  /// The walk goes one level deep and no further: the packages sit side by side
  /// under the root, and a package's own subdirectories carry the same names it
  /// does. `realtime/deploy/services/realtime/` holds a compose fragment, and it
  /// is a service of `realtime` rather than a package of its own.
  ///
  /// A root that does not exist yields nothing rather than failing, since a
  /// project can be read before its framework is vendored in.
  /// Every package a project may mount: what the checkout carries, plus what the
  /// manifest points at with a `path:` or clones with a `git:`.
  ///
  /// A package the project wrote wins over one of the same name in the checkout,
  /// so a project may put its own in front of a shipped one without renaming it.
  ///
  /// Naming a [root] asks a different question: what sits in that directory. The
  /// manifest is not read then, because the caller is not standing in a project.
  static Packages load({Directory? root}) {
    final Directory searched = root ?? globals.fs.directory(globals.project.sdk.packages.path);
    final List<Package> found = <Package>[];
    final Map<String, (LockSource, String?)> locations = <String, (LockSource, String?)>{};

    if (searched.existsSync()) {
      for (final Directory child in searched.listSync(followLinks: false).whereType<Directory>()) {
        if (_isPackage(child)) {
          final String name = p.basename(child.path);
          found.add(Package(name: name, directory: child));
          locations[name] = (LockSource.sdk, null);
        }
      }
    }

    if (root != null) {
      return Packages(found..sort((Package a, Package b) => a.name.compareTo(b.name)), locations);
    }

    for (final MapEntry<String, ProjectDependencySource> entry in globals.project.manifest.packageSources.entries) {
      final (Directory, LockSource, String?)? at = _locate(entry.key, entry.value);
      if (at == null || !at.$1.existsSync() || !_isPackage(at.$1)) continue;

      found
        ..removeWhere((Package carried) => carried.name == entry.key)
        ..add(Package(name: entry.key, directory: at.$1));
      locations[entry.key] = (at.$2, at.$3);
    }

    found.sort((Package a, Package b) => a.name.compareTo(b.name));
    return Packages(found, locations);
  }

  /// Where `config.yaml` sends [name] to be found, as [source] wrote it, or null
  /// for one the checkout ships.
  static (Directory, LockSource, String?)? _locate(String name, ProjectDependencySource source) {
    switch (source) {
      case CheckoutSource():
        return null;
      case PathSource(:final String path):
        final Directory at = globals.fs.directory(p.normalize(p.join(globals.project.directory.path, path)));
        return (at, LockSource.path, null);
      case GitSource():
        final (Directory at, String commit) = resolveGit(
          name,
          source,
          where: '"$name" in ${globals.project.manifest.file.path}',
        );
        return (at, LockSource.git, commit);
    }
  }

  /// Whether [directory] carries any of [packageArtefacts].
  static bool _isPackage(Directory directory) => packageArtefacts.any(
    (String artefact) =>
        directory.fileSystem.typeSync(p.join(directory.path, artefact), followLinks: false) !=
        FileSystemEntityType.notFound,
  );

  /// The packages the current project mounts, what those in turn depend on included.
  List<Package> get active => transitive(globals.project.manifest.packages);

  /// The Compose profiles [mounted] asks for, sorted, without repetition.
  ///
  /// Several packages may share one: mounting any of them switches the whole
  /// profile on, and every service under it starts. A package whose services
  /// name no profile has services that always start.
  static List<String> profilesOf(Iterable<Package> mounted) =>
      <String>{for (final Package package in mounted) ...package.profiles}.toList()..sort();

  /// The package called [name], or null when there is none.
  Package? byName(String name) {
    for (final Package package in all) {
      if (package.name == name) return package;
    }
    return null;
  }

  /// The packages [wanted] asks for, plus the one called [foundationName].
  ///
  /// A package is mounted because a project named it, and for no other reason.
  /// Nothing is pulled in behind the back of whoever wrote the list, which is
  /// what lets a package be mounted alone: what it needs from a neighbour it
  /// asks for at the endpoint that needs it, where the project can be told
  /// what is missing rather than silently given it.
  ///
  /// They come back in the order [wanted] names them, with [foundationName]
  /// first because everything else stands on it. The order is not decoration: a
  /// package fills a port only when nothing has, so the first to answer wins, and
  /// a project that names its own package ahead of a shipped one gets its driver.
  ///
  /// Throws a [ToolExit] naming the known packages when [wanted] holds a name
  /// that is not one.
  List<Package> selected(List<String> wanted) {
    for (final String name in wanted) {
      if (byName(name) == null) {
        throwToolExit(
          'config.yaml: unknown package "$name". The '
          'known ones are ${all.map((Package package) => package.name).join(', ')}.',
        );
      }
    }

    final List<String> order = <String>[foundationName, ...wanted.where((String name) => name != foundationName)];
    return <Package>[
      for (final String name in order)
        if (byName(name) != null) byName(name)!,
    ];
  }

  /// [selected] for [wanted], with what each of them depends on pulled in too.
  ///
  /// A package mounted by name asks for what its own `package.yaml` declares
  /// under `dependencies:`, breadth first so a diamond costs one visit and a
  /// cycle terminates. Unlike resolving one in isolation in
  /// `package/resolution.dart`, this never fetches anything of its own: a
  /// project vendors one copy of everything, so a name is checked against what
  /// the project already mounts, [selected] included, rather than searched for
  /// a second time. A [SdkSource] entry is also checked against the version
  /// the project actually mounts, because a package written against a version
  /// this checkout does not ship would otherwise fail far from the line that
  /// named it; a [PathSource] or a [GitSource] carries no version to compare,
  /// so only its presence is asked for.
  ///
  /// A package with no `package.yaml` declares nothing: [selected] already
  /// recognises a directory as a package from artefacts other than the
  /// manifest, and one that carries none is read as depending on nothing rather
  /// than refused.
  ///
  /// Throws a [ToolExit] naming every dependency that could not be answered,
  /// together: one this checkout carries nothing called, and one whose mounted
  /// version does not satisfy what asked for it.
  List<Package> transitive(List<String> wanted) {
    final List<Package> direct = selected(wanted);
    final Map<String, Package> found = <String, Package>{for (final Package package in direct) package.name: package};
    final List<Package> pending = List<Package>.of(direct);
    final List<String> problems = <String>[];

    while (pending.isNotEmpty) {
      final Package current = pending.removeAt(0);
      final File manifestFile = current.directory.childFile(kManifestFile);
      if (!manifestFile.existsSync()) continue;

      final Manifest manifest = Manifest.parse(manifestFile.readAsStringSync(), manifestFile.path);
      manifest.dependencies.forEach((String name, DependencySource source) {
        final Package? dependency = found[name] ?? byName(name);
        final File? dependencyManifestFile = dependency?.directory.childFile(kManifestFile);
        if (dependency == null || dependencyManifestFile == null || !dependencyManifestFile.existsSync()) {
          problems.add('$name: ${manifest.name} depends on it, and this checkout carries no package of that name.');
          return;
        }

        if (source is SdkSource) {
          final Manifest dependencyManifest = Manifest.parse(
            dependencyManifestFile.readAsStringSync(),
            dependencyManifestFile.path,
          );
          if (!allows(source.constraint, dependencyManifest.version)) {
            problems.add(
              '$name: ${manifest.name} accepts ${source.constraint}, and this project mounts '
              '${dependencyManifest.version}.',
            );
          }
        }

        if (found.containsKey(name)) return;
        found[name] = dependency;
        pending.add(dependency);
      });
    }

    if (problems.isNotEmpty) {
      throwToolExit(
        '${problems.length == 1 ? 'A dependency' : '${problems.length} dependencies'} of a mounted package '
        'could not be answered:\n${problems.map((String problem) => '  $problem').join('\n')}',
      );
    }

    return <Package>[
      ...direct,
      for (final Package package in found.values)
        if (!direct.contains(package)) package,
    ];
  }

  /// What [mounted] freezes into a project's [kProjectLockFile]: every one of
  /// them at the version it publishes, [scribe] the project vendors, and where
  /// [load] found it.
  ///
  /// The source comes from [_locations], not from comparing [Package.directory]
  /// against the checkout's `packages/` after the fact: a git dependency's
  /// directory sits under the tool's own cache, and nothing about that path
  /// says so on its own the way it does for the checkout's `packages/` or a
  /// `path:`.
  PackageLock lockOf(List<Package> mounted, String scribe) {
    return PackageLock(
      scribe: scribe,
      packages: <LockedPackage>[
        for (final Package package in mounted)
          LockedPackage(
            name: package.name,
            version: Manifest.parse(
              package.directory.childFile(kManifestFile).readAsStringSync(),
              package.directory.childFile(kManifestFile).path,
            ).version,
            source: _locations[package.name]!.$1,
            resolvedRef: _locations[package.name]!.$2,
          ),
      ]..sort((LockedPackage a, LockedPackage b) => a.name.compareTo(b.name)),
    );
  }

  /// The slices of [template] declared by [active], in the order they are given.
  ///
  /// A package that declares none is skipped rather than contributing an empty
  /// block, so the merged document only names the packages that had something
  /// to add to it.
  List<YamlFragment> fragmentsFor(String template, List<Package> active) => <YamlFragment>[
    for (final Package package in active) ...package.fragmentsFor(template),
  ];
}

/// A `profiles:` key, whatever depth it sits at, with whatever follows it.
final RegExp _profilesKey = RegExp(r'^\s*profiles:(.*)$');

/// An item of a YAML block sequence.
final RegExp _listItem = RegExp(r'^\s*-\s*(.+)$');

/// Every quote, comma and bracket a flow sequence spells its names with.
final RegExp _flowPunctuation = RegExp(r"""[\[\],"']""");

/// The profile names [source] carries, in either the flow or the block form.
///
/// This reads lines rather than a parsed document, the way [mergeYamlDocuments]
/// does and for the same reason: a fragment holds `{{placeholders}}` that are
/// not valid YAML values until they are rendered.
Set<String> _profilesIn(String source) {
  final List<String> lines = source.split('\n');
  final Set<String> found = <String>{};

  for (int index = 0; index < lines.length; index++) {
    final RegExpMatch? key = _profilesKey.firstMatch(lines[index]);
    if (key == null) continue;

    found.addAll(_namesIn(key.group(1)!));
    for (int next = index + 1; next < lines.length; next++) {
      final RegExpMatch? item = _listItem.firstMatch(lines[next]);
      if (item == null) break;
      found.addAll(_namesIn(item.group(1)!));
    }
  }

  return found;
}

/// The names [value] holds, stripped of the punctuation a flow sequence adds.
Iterable<String> _namesIn(String value) => value
    .replaceAll(_flowPunctuation, ' ')
    .split(' ')
    .map((String name) => name.trim())
    .where((String name) => name.isNotEmpty);
