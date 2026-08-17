// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/scribe_manifest.dart';
import 'package:scribe/src/sdk_target.dart';

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

  /// The modules this project mounts, each one holding a `scribe.yaml`.
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

  /// The modules the project mounts, as the host reads them.
  File get dependencies => directory.childFile('dependencies.ts');

  /// The route table the scanner found under `lib/`.
  File get routes => directory.childFile('routes.ts');

  /// The typed PostgREST client.
  GeneratedRest get rest => GeneratedRest(directory.childDirectory('rest'));

  /// Creates this directory and everything above it.
  Future<void> create() => directory.create(recursive: true);
}

/// The typed PostgREST client, under `.<name>/sdk/js/rest/`.
class GeneratedRest {
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
  const ScribeSdk(this.directory);

  /// The directory itself.
  final Directory directory;

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The process that serves the API.
  Directory get host => directory.childDirectory('host');

  /// The host's Deno configuration, which its import map is merged into.
  File get hostDenoJson => host.childFile('deno.json');

  /// The environment variables the host reads, and their types.
  File get hostEnv => host.childFile('env.ts');

  /// The endpoints the framework serves on its own.
  Directory get hostApi => host.childDirectory('api');

  /// The modules the framework owns, each one holding a `scribe.yaml`.
  Directory get hostDependencies => host.childDirectory('dependencies');

  /// The mountable packages, in the submodule that carries them.
  ///
  /// Same shape as [hostDependencies] and read the same way: the two are
  /// searched together, and a module is addressed relative to whichever holds
  /// it. Absent from a clone made without `--recurse-submodules`, which is why
  /// nothing may assume it exists.
  Directory get hostPackages => host.childDirectory('packages');

  /// The primitive package, `@scribe/core`.
  Directory get hostCore => host.childDirectory('core');

  /// The SQL run once on an empty database.
  Directory get hostDbInit => hostCore.childDirectory('db').childDirectory('init');

  /// The SQL run in order on a database that already holds data.
  Directory get hostDbMigrations => hostCore.childDirectory('db').childDirectory('migrations');

  /// The SQL that creates the roles and the grants.
  Directory get hostDbProvisioning => hostCore.childDirectory('db').childDirectory('provisioning');

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
