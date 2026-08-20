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

/// The directory, inside a module, holding its slices of the ops templates.
const String fragmentDirectory = 'ops';

/// The directory, inside a module, holding its SQL.
const String sqlDirectory = 'db';

/// The subdirectory of [sqlDirectory] played when the stack is built.
///
/// A module's `db/` also holds `migrations/` and `provisioning/`, which are
/// played by other hands and at another moment.
const String sqlInitDirectory = 'init';

/// The directory, inside a module, holding its contract.
const String protocolDirectory = 'protocol';

/// The file a module writes to hand the framework what it provides.
const String registrationFile = 'register.ts';

/// The file a package declares its name and its exports in.
const String packageFile = 'deno.json';

/// The template a module declares its services in, and the profiles they sit behind.
const String composeTemplate = 'docker-compose.yaml';

/// What a directory has to carry to be a module.
///
/// These are the five things the tools read from a module, and a directory that
/// carries none of them holds nothing a project could mount. Nothing is
/// declared anywhere: a module is recognised by what it is made of, so there is
/// no second place where the list of modules could disagree with the tree.
const Set<String> moduleArtefacts = <String>{
  fragmentDirectory,
  sqlDirectory,
  protocolDirectory,
  registrationFile,
  packageFile,
};

/// The one module a project gets whether or not it names it.
///
/// It is not a preference: the framework does not compile without it. Every
/// other module is mounted when `config.yaml` asks for it by name, and never
/// otherwise.
const String foundationPath = 'foundation';

/// One mountable module, recognised by the artefacts its directory carries.
class Dependency {
  /// Holds the module addressed by [path], living in [directory].
  const Dependency({required this.path, required this.directory});

  /// The module's address, relative to the dependencies root: `security/auth`.
  ///
  /// This is what `config.yaml` names a module by.
  final String path;

  /// The directory the module lives in.
  final Directory directory;

  /// The SQL this module adds to the database, null when it ships none.
  Directory? get sql {
    final Directory found = directory.childDirectory(sqlDirectory).childDirectory(sqlInitDirectory);
    return found.existsSync() ? found : null;
  }

  /// The Compose profiles this module's services sit behind.
  ///
  /// Read from the fragments rather than declared next to them: the `profiles:`
  /// key of a service is what Compose obeys, so a second copy would be the one
  /// that drifts, and it would drift towards giving a share of the machine to a
  /// container nothing ever starts.
  Set<String> get profiles => <String>{
    for (final File fragment in fragments(composeTemplate)) ..._profilesIn(fragment.readAsStringSync()),
  };

  /// The files this module's slices of [template] would be read from.
  ///
  /// A package groups its ops by subject, so `ops/valkery/docker-compose.yaml`
  /// counts as much as `ops/docker-compose.yaml`. None of them is required to
  /// exist: a module contributes to the templates it has something to say
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

  /// This module's slices of [template], one per subject that declares one.
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
    return subject == fragmentDirectory ? path : '$path/$subject';
  }
}

/// Every module found under the dependency roots.
class Dependencies {
  /// Holds [all] the modules one walk found.
  const Dependencies(this.all);

  /// Every module found, sorted by [Dependency.path].
  final List<Dependency> all;

  /// Every module under [roots], the project's vendored framework by default.
  ///
  /// There are two roots and not one because a module can live in either of two
  /// repositories: `host/dependencies/` holds what the framework owns, and
  /// `host/packages/` is the submodule where the mountable packages live. A
  /// module's address stays relative to the root that carries it, so moving one
  /// between the two leaves `security/auth` spelled `security/auth`, which is
  /// what a project wrote in its `config.yaml`, and what must not break.
  ///
  /// A root that does not exist yields nothing rather than failing: a project
  /// can be read before its framework is vendored in, and a clone without
  /// `--recurse-submodules` has no `host/packages/` at all.
  static Dependencies load({List<Directory>? roots}) {
    final List<Directory> searched = roots ?? _defaultRoots();
    final List<Dependency> found = <Dependency>[];

    for (final Directory modules in searched) {
      if (!modules.existsSync()) continue;
      _collect(modules, modules, found);
    }

    found.sort((Dependency a, Dependency b) => a.path.compareTo(b.path));
    return Dependencies(found);
  }

  /// Adds the modules under [directory] to [found], addressed against [root].
  ///
  /// The walk descends until it recognises a module and never enters one, since
  /// a module's own subdirectories carry the same names it does:
  /// `foundation/ops/database/` holds a compose fragment, and it is a subject of
  /// `foundation` rather than a module of its own. That is also what lets a
  /// family hold as many levels as it needs, `geospatial` sitting one level
  /// under its root and `security/auth` two.
  static void _collect(Directory directory, Directory root, List<Dependency> found) {
    for (final Directory child in directory.listSync(followLinks: false).whereType<Directory>()) {
      if (_isModule(child)) {
        found.add(
          Dependency(
            path: p.relative(child.path, from: root.path),
            directory: child,
          ),
        );
        continue;
      }

      _collect(child, root, found);
    }
  }

  /// Whether [directory] carries any of [moduleArtefacts].
  static bool _isModule(Directory directory) => moduleArtefacts.any(
    (String artefact) =>
        directory.fileSystem.typeSync(p.join(directory.path, artefact), followLinks: false) !=
        FileSystemEntityType.notFound,
  );

  static List<Directory> _defaultRoots() => <Directory>[
    globals.fs.directory(globals.project.sdk.hostDependencies.path),
    globals.fs.directory(globals.project.sdk.hostPackages.path),
  ];

  /// The modules the current project mounts.
  List<Dependency> get active => selected(globals.project.manifest.dependencies);

  /// The Compose profiles [mounted] asks for, sorted, without repetition.
  ///
  /// Several modules may share one: mounting any of them switches the whole
  /// profile on, and every service under it starts. A module whose services
  /// name no profile has services that always start.
  static List<String> profilesOf(Iterable<Dependency> mounted) =>
      <String>{for (final Dependency dependency in mounted) ...dependency.profiles}.toList()..sort();

  /// The module at [path], or null when there is none.
  Dependency? byPath(String path) {
    for (final Dependency dependency in all) {
      if (dependency.path == path) return dependency;
    }
    return null;
  }

  /// The modules [wanted] asks for, plus the one at [foundationPath].
  ///
  /// A module is mounted because a project named it, and for no other reason.
  /// Nothing is pulled in behind the back of whoever wrote the list, which is
  /// what lets a package be mounted alone: what it needs from a neighbour it
  /// asks for at the endpoint that needs it, where the project can be told
  /// what is missing rather than silently given it.
  ///
  /// Throws a [ToolExit] naming the known modules when [wanted] holds a path
  /// that is not one.
  List<Dependency> selected(List<String> wanted) {
    for (final String path in wanted) {
      if (byPath(path) == null) {
        throwToolExit(
          'config.yaml: unknown dependency "$path". The '
          'known ones are ${all.map((Dependency d) => d.path).join(', ')}.',
        );
      }
    }

    final Set<String> keep = <String>{foundationPath, ...wanted};
    return all.where((Dependency dependency) => keep.contains(dependency.path)).toList();
  }

  /// The slices of [template] declared by [active], in the order they are given.
  ///
  /// A module that declares none is skipped rather than contributing an empty
  /// block, so the merged document only names the modules that had something
  /// to add to it.
  List<YamlFragment> fragmentsFor(String template, List<Dependency> active) => <YamlFragment>[
    for (final Dependency dependency in active) ...dependency.fragmentsFor(template),
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
