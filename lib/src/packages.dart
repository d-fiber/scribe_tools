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

/// The directory, inside a package, holding its slices of the ops templates.
const String fragmentDirectory = 'ops';

/// The directory, inside a package, holding its SQL.
const String sqlDirectory = 'db';

/// The subdirectory of [sqlDirectory] played when the stack is built.
///
/// A package's `db/` also holds `migrations/` and `provisioning/`, which are
/// played by other hands and at another moment.
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
/// These are the five things the tools read from a package, and a directory
/// that carries none of them holds nothing a project could mount. Nothing is
/// declared anywhere: a package is recognised by what it is made of, so there
/// is no second place where the list of packages could disagree with the tree.
const Set<String> packageArtefacts = <String>{
  fragmentDirectory,
  sqlDirectory,
  protocolDirectory,
  registrationFile,
  packageFile,
};

/// The one package a project gets whether or not it names it.
///
/// It is not a preference: the framework does not compile without it. Every
/// other package is mounted when `config.yaml` asks for it by name, and never
/// otherwise.
const String foundationName = 'foundation';

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
    final Directory found = directory.childDirectory(sqlDirectory).childDirectory(sqlInitDirectory);
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
  /// A package groups its ops by subject, so `ops/valkery/docker-compose.yaml`
  /// counts as much as `ops/docker-compose.yaml`. None of them is required to
  /// exist: a package contributes to the templates it has something to say
  /// about and to no others.
  List<File> fragments(String template) {
    final Directory ops = directory.childDirectory(fragmentDirectory);
    if (!ops.existsSync()) return const <File>[];

    final List<File> found = <File>[ops.childFile(template)];
    for (final Directory subject in ops.listSync().whereType<Directory>()) {
      found.add(subject.childFile(template));
    }

    return found.where((File file) => file.existsSync()).toList()..sort((File a, File b) => a.path.compareTo(b.path));
  }

  /// This package's slices of [template], one per subject that declares one.
  List<YamlFragment> fragmentsFor(String template) => <YamlFragment>[
    for (final File file in fragments(template)) YamlFragment(_labelOf(file), file.readAsStringSync()),
  ];

  /// The name written into the merged document above a fragment's block.
  ///
  /// A fragment that sits in a subject directory names the subject too, so a
  /// reader of the generated compose can tell `foundation/valkery` from
  /// `foundation/queue`.
  String _labelOf(File file) {
    final String subject = p.basename(file.parent.path);
    return subject == fragmentDirectory ? name : '$name/$subject';
  }
}

/// Every package found under the packages root.
class Packages {
  /// Holds [all] the packages one walk found.
  const Packages(this.all);

  /// Every package found, sorted by [Package.name].
  final List<Package> all;

  /// Every package directly under [root], the project's vendored `packages/`.
  ///
  /// The walk goes one level deep and no further: the packages sit side by side
  /// under the root, and a package's own subdirectories carry the same names it
  /// does. `foundation/ops/database/` holds a compose fragment, and it is a
  /// subject of `foundation` rather than a package of its own.
  ///
  /// A root that does not exist yields nothing rather than failing, since a
  /// project can be read before its framework is vendored in.
  static Packages load({Directory? root}) {
    final Directory searched = root ?? globals.fs.directory(globals.project.sdk.packages.path);
    final List<Package> found = <Package>[];

    if (searched.existsSync()) {
      for (final Directory child in searched.listSync(followLinks: false).whereType<Directory>()) {
        if (_isPackage(child)) {
          found.add(Package(name: p.basename(child.path), directory: child));
        }
      }
    }

    found.sort((Package a, Package b) => a.name.compareTo(b.name));
    return Packages(found);
  }

  /// Whether [directory] carries any of [packageArtefacts].
  static bool _isPackage(Directory directory) => packageArtefacts.any(
    (String artefact) =>
        directory.fileSystem.typeSync(p.join(directory.path, artefact), followLinks: false) !=
        FileSystemEntityType.notFound,
  );

  /// The packages the current project mounts.
  List<Package> get active => selected(globals.project.manifest.packages);

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

    final Set<String> keep = <String>{foundationName, ...wanted};
    return all.where((Package package) => keep.contains(package.name)).toList();
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
