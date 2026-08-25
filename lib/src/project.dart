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
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:scribe_tools/src/sdk_target.dart';

/// A scribe project on disk, and every path derived from where it sits.
///
/// Nothing here is static: a [Project] is a directory, and every getter is a
/// path relative to it. That is what lets a generator run against an arbitrary
/// project, and against a `MemoryFileSystem` in a test.
///
/// The tree splits three ways. What the user writes is under [lib]; what the
/// tool derives is under [generated], a directory named after the project; what
/// the framework provides is under [sdk].
class Project {
  Project._(this.directory);

  /// The file whose presence makes a directory a project root.
  static const String configFileName = 'config.yaml';

  /// The project rooted at [directory], whether or not one is really there.
  static Project fromDirectory(Directory directory) => Project._(directory.absolute);

  /// Whether [directory] holds a [configFileName].
  static bool isProjectRoot(Directory directory) => directory.childFile(configFileName).existsSync();

  /// The nearest project at or above [start], or null when there is none.
  ///
  /// This is only ever used to improve an error message. A command runs at the
  /// root and nowhere else, the way `flutter` needs `pubspec.yaml` in the
  /// current directory. See [current].
  static Project? findAbove(Directory start) {
    Directory candidate = start.absolute;

    while (true) {
      if (isProjectRoot(candidate)) return Project._(candidate);

      final Directory parent = candidate.parent;
      if (parent.path == candidate.path) return null;
      candidate = parent;
    }
  }

  /// The project the current directory is the root of, or null when it is not one.
  static Project? get currentOrNull {
    final Directory here = globals.fs.currentDirectory;
    return isProjectRoot(here) ? Project._(here.absolute) : null;
  }

  /// The project the current directory is the root of.
  ///
  /// The search never walks up: a command runs at the root or not at all.
  ///
  /// Throws a [ToolExit] when the current directory is not one, naming the
  /// project above when [findAbove] finds one so the user is told where to go.
  static Project get current {
    final Project? here = currentOrNull;
    if (here != null) return here;

    throwToolExit(_notAtRoot(globals.fs.currentDirectory));
  }

  static String _notAtRoot(Directory here) {
    final Project? above = findAbove(here);

    if (above == null) {
      return 'This command must run from the root of a scribe project, the directory that holds $configFileName.\n'
          'There is none here, nor in any directory above. Run `scribe create <name>` to start one.';
    }

    return 'This command must run from the root of a scribe project, the directory that holds $configFileName.\n'
        'One is at ${above.directory.path}: cd there and run it again.';
  }

  /// The root, the directory holding [configFileName].
  final Directory directory;

  /// The project's name, which is the name of its root directory.
  String get name => directory.basename;

  /// The name of the directory everything derived is written to, `.<name>`.
  String get generatedDirectoryName => '.$name';

  /// The import prefix the generated sources are reached by, `@<name>/`.
  String get generatedAlias => '@$name/';

  /// The manifest, `config.yaml`.
  File get config => directory.childFile(configFileName);

  /// The manifest a new project is filled in from.
  File get configExample => directory.childFile('config.example.yaml');

  /// The file the values `config.yaml` reads through `env(...)` come from.
  File get env => directory.childFile('.env');

  /// The X25519 key written before it is turned into an age identity.
  ///
  /// It only exists between the two steps: a file left here means the key was
  /// generated and never adopted.
  File get pendingX25519Pem => directory.childFile('.tmp_x25519.pem');

  /// The images, fonts and files the project serves as they are.
  Directory get assets => directory.childDirectory('assets');

  /// Everything the user writes.
  Directory get lib => directory.childDirectory('lib');

  /// The SDK this project targets, [kDefaultSdkName] when the manifest names none.
  String get sdkName {
    final String declared = ScribeManifest.loadFrom(config)?.sdk ?? '';
    return declared.isEmpty ? kDefaultSdkName : sdkDirectoryFor(declared);
  }

  /// The extension the project's sources carry, read from the entrypoint that is there.
  ///
  /// It is read from the file rather than from the SDK name because the two can
  /// disagree while a project is being moved from one target to another.
  String get sourceExtension => p.extension(_existingEntrypoint()?.path ?? 'main.ts');

  /// The file the host loads the project through, `lib/main.<ext>`.
  ///
  /// The file that is there when there is one, and where it would go otherwise.
  File get entrypoint => _existingEntrypoint() ?? lib.childFile('main$sourceExtension');

  File? _existingEntrypoint() {
    if (!lib.existsSync()) return null;

    for (final FileSystemEntity entity in lib.listSync(followLinks: false)) {
      if (entity is File && p.basenameWithoutExtension(entity.path) == 'main') return entity;
    }
    return null;
  }

  /// The business logic: the tables, the routes, the extensions.
  Directory get sources => lib.childDirectory('src');

  /// The project's own local modules, under `lib/dependencies/`.
  ///
  /// Not what `config.yaml` mounts: the packages a project mounts come from the
  /// checkout, and this directory holds code the project itself writes.
  Directory get dependencies => lib.childDirectory('dependencies');

  /// The public pages this project serves.
  Directory get hostings => lib.childDirectory('hostings');

  /// The mail templates.
  Directory get mails => lib.childDirectory('mails');

  /// The text-message templates.
  Directory get sms => lib.childDirectory('sms');

  /// The colours and fonts the templates render with.
  Directory get theme => lib.childDirectory('theme');

  /// The SQL run once, when the database is empty.
  Directory get init => directory.childDirectory('init');

  /// The SQL run in order on a database that already holds data.
  Directory get migrations => directory.childDirectory('migrations');

  /// The project's own tests.
  Directory get tests => directory.childDirectory('tests');

  /// Everything the tool derives, under `.<name>/`.
  ///
  /// Nothing in there is written by hand, and every generator is free to
  /// overwrite it.
  GeneratedDirectory get generated => GeneratedDirectory(directory.childDirectory(generatedDirectoryName));

  /// The framework vendored into the project, under `scribe/`.
  ScribeSdk get sdk => ScribeSdk(directory.childDirectory('scribe'));

  /// The parsed `config.yaml`, read once and kept.
  ///
  /// Throws a [ToolExit] when the file is missing or is not a YAML mapping.
  ScribeManifest get manifest => _manifest ??= ScribeManifest.load(config);

  ScribeManifest? _manifest;

  /// Whether this directory holds a `config.yaml`, and so is a project root.
  bool get exists => config.existsSync();

  /// The entries a project needs and this one does not have, empty when it is whole.
  ///
  /// A directory can hold a `config.yaml` and nothing else, which is why being
  /// at the root is checked separately from being usable.
  List<String> get missingEntries => <String>[
    if (!config.existsSync()) configFileName,
    if (!lib.existsSync()) 'lib/',
    if (!entrypoint.existsSync()) 'lib/main$sourceExtension',
    if (!sources.existsSync()) 'lib/src/',
  ];

  /// Whether every entry a project needs is there.
  bool get isUsable => missingEntries.isEmpty;

  @override
  String toString() => 'Project($name at ${directory.path})';
}

/// The `.<name>/` directory, holding everything the tool writes.
class GeneratedDirectory {
  /// Reads the generated tree at [directory].
  const GeneratedDirectory(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The generated client the project imports.
  GeneratedSdk get sdk => GeneratedSdk(directory.childDirectory('sdk').childDirectory('js'));

  /// The OpenAPI documents `gen docs` produces.
  GeneratedDocs get docs => GeneratedDocs(directory.childDirectory('docs'));

  /// The compose files and gateway configuration the stack is started from.
  Directory get ops => directory.childDirectory('ops');
}

/// The generated client, under `.<name>/sdk/js/`.
class GeneratedSdk {
  /// Reads the generated client at [directory].
  const GeneratedSdk(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The import map that resolves `@<name>/` on the host.
  File get importMap => directory.childFile('scribe.json');

  /// The import map used inside the container, where the paths differ.
  File get containerImportMap => directory.childFile('scribe.container.json');

  /// The enum types mirrored from the SQL schema.
  File get enums => directory.childFile('enums.ts');

  /// The country codes the firewall lets through, from `api.config.allowed_countries`.
  File get allowedCountries => directory.childFile('allowed_countries.ts');

  /// The packages the project mounts, as the host reads them.
  File get packages => directory.childFile('packages.ts');

  /// The `register.ts` of every mounted package, imported for its effect.
  ///
  /// This is what hands the framework's ports their implementations. The host
  /// imports this one file and names no package itself, so mounting a new one
  /// never edits the framework.
  File get registrations => directory.childFile('registrations.ts');

  /// The route table the scanner found under `lib/`.
  File get routes => directory.childFile('routes.ts');

  /// The functions the host loads the project's own declarations through.
  ///
  /// One per bucket a mounted package opened, each answering the files of that
  /// kind found under `lib/`. They are kept apart because the host calls them at
  /// different moments.
  File get declarations => directory.childFile('declarations.ts');

  /// The typed PostgREST client.
  GeneratedRest get rest => GeneratedRest(directory.childDirectory('rest'));

  /// Creates this directory and everything above it.
  Future<void> create() => directory.create(recursive: true);
}

/// The typed PostgREST client, under `.<name>/sdk/js/rest/`.
class GeneratedRest {
  /// Reads the generated PostgREST client at [directory].
  const GeneratedRest(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// One row type per table, mirrored from the SQL schema.
  File get rows => directory.childFile('_rows.generated.ts');

  /// The column each table is owned through, which is what scopes a query.
  File get owners => directory.childFile('_owners.ts');

  /// The table handles a query starts from.
  File get tables => directory.childFile('tables.ts');

  /// The client the host calls PostgREST with.
  File get client => directory.childFile('client.ts');

  /// The client a worker calls PostgREST with, under its own scope.
  File get worker => directory.childFile('worker.ts');

  /// Creates this directory and everything above it.
  Future<void> create() => directory.create(recursive: true);
}

/// The OpenAPI documents, under `.<name>/docs/`.
class GeneratedDocs {
  /// Reads the generated OpenAPI documents at [directory].
  const GeneratedDocs(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The list of surfaces, which is what the portal reads first.
  File get index => directory.childFile('index.json');

  /// The OpenAPI document of the surface named [key], one per `api.docs` entry.
  File surface(String key) => directory.childFile('$key.yaml');

  /// Creates this directory and everything above it.
  Future<void> create() => directory.create(recursive: true);
}

/// The framework vendored into the project, under `scribe/`.
///
/// This is a copy of the `scribe` repository, so the layout below mirrors it.
class ScribeSdk {
  /// Reads the vendored framework at [directory].
  const ScribeSdk(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The process that serves the API.
  Directory get engine => directory.childDirectory('engine');

  /// The checkout's own Deno configuration, which its import map is merged into.
  ///
  /// It sits at the root and not under `engine/`, because scribe is one Deno
  /// project: the root is the workspace, and it is the only place that names a
  /// version and pins what is outside the framework. Each layer under `engine/`
  /// carries a configuration of its own, but those name only the layers they may
  /// reach and are of no use to a project.
  File get denoJson => directory.childFile('deno.json');

  /// The endpoints the framework serves on its own.
  Directory get engineApi => engine.childDirectory('api');

  /// The mountable packages, the one root the walk that finds them reads.
  ///
  /// It sits at the checkout root and not under `engine/`, next to the other
  /// members of the Deno workspace, which is also where the import map the CLI
  /// writes resolves `@scribe/<name>/` to. A package is addressed by the name of
  /// its directory here, and by nothing else.
  Directory get packages => directory.childDirectory('packages');

  /// The base schema, which is SQL and therefore sits beside the engine, not inside it.
  Directory get db => directory.childDirectory('db');

  /// The SQL run once on an empty database.
  Directory get dbInit => db.childDirectory('init');

  /// The SQL run in order on a database that already holds data.
  Directory get dbMigrations => db.childDirectory('migrations');

  /// The SQL that creates the roles and the grants.
  Directory get dbProvisioning => db.childDirectory('provisioning');

  /// What the stack mounts or builds as it is, from Dockerfiles to the Caddyfile.
  ///
  /// Nothing here carries a placeholder. Everything that does lives under
  /// [templates] instead, so that a file read from this directory is always a
  /// file Docker can use directly.
  Directory get ops => directory.childDirectory('ops');

  /// Everything the tool renders rather than reads, under `templates/`.
  Directory get templates => directory.childDirectory('templates');

  /// The compose and gateway templates a project's stack is rendered from.
  Directory get opsTemplates => templates.childDirectory('ops');

  /// The `.proto` files of the host-to-worker contract.
  Directory get protocol => directory.childDirectory('protocol');

  /// The documentation portal.
  Directory get web => directory.childDirectory('web');
}
