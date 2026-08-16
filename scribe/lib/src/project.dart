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

class Project {
  Project._(this.directory);

  static const String configFileName = 'config.yaml';

  static Project fromDirectory(Directory directory) => Project._(directory.absolute);

  static bool isProjectRoot(Directory directory) => directory.childFile(configFileName).existsSync();

  static Project? findAbove(Directory start) {
    Directory candidate = start.absolute;

    while (true) {
      if (isProjectRoot(candidate)) return Project._(candidate);

      final Directory parent = candidate.parent;
      if (parent.path == candidate.path) return null;
      candidate = parent;
    }
  }

  static Project? get currentOrNull {
    final Directory here = globals.fs.currentDirectory;
    return isProjectRoot(here) ? Project._(here.absolute) : null;
  }

  static Project get current {
    final Project? here = currentOrNull;
    if (here != null) return here;

    throwToolExit(_notAtRoot(globals.fs.currentDirectory));
  }

  static String _notAtRoot(Directory here) {
    final Project? above = findAbove(here);

    if (above == null) {
      return 'This command must run from the root of a scribe project — the directory that holds $configFileName.\n'
          'There is none here, nor in any directory above. Run `scribe create <name>` to start one.';
    }

    return 'This command must run from the root of a scribe project — the directory that holds $configFileName.\n'
        'One is at ${above.directory.path}: cd there and run it again.';
  }

  final Directory directory;

  String get name => directory.basename;

  String get generatedDirectoryName => '.$name';

  String get generatedAlias => '@$name/';

  File get config => directory.childFile(configFileName);

  File get configExample => directory.childFile('config.example.yaml');

  File get env => directory.childFile('.env');

  File get pendingX25519Pem => directory.childFile('.tmp_x25519.pem');

  Directory get assets => directory.childDirectory('assets');

  Directory get lib => directory.childDirectory('lib');

  String get sdkName {
    final String declared = ScribeManifest.loadFrom(config)?.sdk ?? '';
    return declared.isEmpty ? kDefaultSdkName : declared;
  }

  String get sourceExtension => p.extension(_existingEntrypoint()?.path ?? 'main.ts');

  File get entrypoint => _existingEntrypoint() ?? lib.childFile('main$sourceExtension');

  File? _existingEntrypoint() {
    if (!lib.existsSync()) return null;

    for (final FileSystemEntity entity in lib.listSync(followLinks: false)) {
      if (entity is File && p.basenameWithoutExtension(entity.path) == 'main') return entity;
    }
    return null;
  }

  Directory get sources => lib.childDirectory('src');

  Directory get dependencies => lib.childDirectory('dependencies');

  Directory get hostings => lib.childDirectory('hostings');

  Directory get mails => lib.childDirectory('mails');

  Directory get sms => lib.childDirectory('sms');

  Directory get theme => lib.childDirectory('theme');

  Directory get init => directory.childDirectory('init');

  Directory get migrations => directory.childDirectory('migrations');

  Directory get tests => directory.childDirectory('tests');

  GeneratedDirectory get generated => GeneratedDirectory(directory.childDirectory(generatedDirectoryName));

  ScribeSdk get sdk => ScribeSdk(directory.childDirectory('scribe'));

  ScribeManifest get manifest => _manifest ??= ScribeManifest.load(config);

  ScribeManifest? _manifest;

  bool get exists => config.existsSync();

  List<String> get missingEntries => <String>[
    if (!config.existsSync()) configFileName,
    if (!lib.existsSync()) 'lib/',
    if (!entrypoint.existsSync()) 'lib/main$sourceExtension',
    if (!sources.existsSync()) 'lib/src/',
  ];

  bool get isUsable => missingEntries.isEmpty;

  @override
  String toString() => 'Project($name at ${directory.path})';
}

class GeneratedDirectory {
  const GeneratedDirectory(this.directory);

  final Directory directory;

  String get path => directory.path;

  GeneratedSdk get sdk => GeneratedSdk(directory.childDirectory('sdk').childDirectory('js'));

  GeneratedDocs get docs => GeneratedDocs(directory.childDirectory('docs'));

  Directory get ops => directory.childDirectory('ops');
}

class GeneratedSdk {
  const GeneratedSdk(this.directory);

  final Directory directory;

  String get path => directory.path;

  File get importMap => directory.childFile('scribe.json');

  File get containerImportMap => directory.childFile('scribe.container.json');

  File get enums => directory.childFile('enums.ts');

  File get allowedCountries => directory.childFile('allowed_countries.ts');

  File get dependencies => directory.childFile('dependencies.ts');

  File get routes => directory.childFile('routes.ts');

  GeneratedRest get rest => GeneratedRest(directory.childDirectory('rest'));

  Future<void> create() => directory.create(recursive: true);
}

class GeneratedRest {
  const GeneratedRest(this.directory);

  final Directory directory;

  String get path => directory.path;

  File get rows => directory.childFile('_rows.generated.ts');

  File get owners => directory.childFile('_owners.ts');

  File get tables => directory.childFile('tables.ts');

  File get client => directory.childFile('client.ts');

  File get worker => directory.childFile('worker.ts');

  Future<void> create() => directory.create(recursive: true);
}

class GeneratedDocs {
  const GeneratedDocs(this.directory);

  final Directory directory;

  String get path => directory.path;

  File get index => directory.childFile('index.json');

  File surface(String key) => directory.childFile('$key.yaml');

  Future<void> create() => directory.create(recursive: true);
}

class ScribeSdk {
  const ScribeSdk(this.directory);

  final Directory directory;

  String get path => directory.path;

  Directory get host => directory.childDirectory('host');

  File get hostDenoJson => host.childFile('deno.json');

  File get hostEnv => host.childFile('env.ts');

  Directory get hostApi => host.childDirectory('api');

  Directory get hostDependencies => host.childDirectory('dependencies');

  Directory get hostCore => host.childDirectory('core');

  Directory get hostDbInit => hostCore.childDirectory('db').childDirectory('init');

  Directory get hostDbMigrations => hostCore.childDirectory('db').childDirectory('migrations');

  Directory get hostDbProvisioning => hostCore.childDirectory('db').childDirectory('provisioning');

  Directory get ops => directory.childDirectory('ops');

  Directory get protocol => directory.childDirectory('protocol');

  Directory get web => directory.childDirectory('web');
}
