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
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:test/test.dart';

import 'sdk_source.dart';

void main() {
  late Directory root;
  late Directory checkout;
  late Directory home;

  setUp(() {
    root = Directory.systemTemp.createTempSync('scribe_resolution_');
    home = Directory.systemTemp.createTempSync('scribe_home_');
    checkout = Directory.systemTemp.createTempSync('scribe_sdk_');
    writeCheckout(
      checkout,
      imports: const <String, String>{
        '@scribe/alchemy': './engine/alchemy/mod.ts',
        '@scribe/alchemy/http': './engine/alchemy/src/http/mod.ts',
        '@scribe/contracts/': './engine/contracts/',
        'croner': 'npm:croner@8',
      },
    );
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    checkout.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  });

  void resolving(String name, void Function() body) => test(name, () => withHome(home, body));

  Sdk sdkOfCheckout() => findSdk(from: checkout.path);

  Map<String, Object?> decoded(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  Map<String, Object?> resolutionOf(String package) => decoded(p.join(package, kResolutionDirectory, kResolutionFile));

  Map<String, Object?> importsOf(String package) => resolutionOf(package)['reaches']! as Map<String, Object?>;

  Map<String, Object?> runtimeConfigOf(String package) => decoded(p.join(runtimeHomeOf(package), kRuntimeConfigFile));

  String packageAt(String parent, String name, String blocks, {String version = '1.0.0'}) {
    final CreatedPackage created = createPackage(parent, name, sdkOfCheckout());
    File(
      p.join(created.directory, kManifestFile),
    ).writeAsStringSync('name: $name\nversion: $version\n\nenvironment:\n  $kEnvironmentKey: "^3.0.0"\n\n$blocks');

    return created.directory;
  }

  String packageDeclaring(String blocks, {String name = 'notifications'}) => packageAt(root.path, name, blocks);

  String carriedByCheckout(String name, String blocks, {String version = '1.0.0'}) =>
      packageAt(p.join(checkout.path, kPackagesDirectory), name, blocks, version: version);

  Matcher refuses(Object saying) =>
      throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', saying));

  resolving('a checkout is recognised by the entry of the language it carries', () {
    final Sdk found = sdkOfCheckout();

    expect(found.root, checkout.path);
    expect(found.version, '3.0.1', reason: 'the checkout published another version');
  });

  resolving('a directory that carries no language entry is not a checkout', () {
    expect(() => findSdk(from: root.path), throwsA(isA<ToolExit>()));
  });

  resolving('every entry the language publishes is reachable, not only its main one', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    final Map<String, Object?> imports = importsOf(created.directory);
    expect(
      imports['@scribe/alchemy/http'],
      Uri.file(p.join(checkout.path, 'engine', 'alchemy', 'src', 'http', 'mod.ts')).toString(),
      reason: 'a sub-entry nobody maps is a sub-entry no package can import',
    );
  });

  resolving('a package reaches its own entry by the name it publishes', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(
      importsOf(created.directory)['@scribe/notifications'],
      Uri.file(p.join(created.directory, 'lib', 'notifications.ts')).toString(),
      reason: 'the entry a package publishes was the one nobody could import',
    );
  });

  resolving('resolving points the language at the checkout it was resolved against', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(
      importsOf(created.directory)['@scribe/alchemy'],
      Uri.file(p.join(checkout.path, 'engine', 'alchemy', 'mod.ts')).toString(),
      reason: 'the language does not point at the checkout',
    );
  });

  resolving('what the checkout pins answers the specifiers the package declared', () {
    final String at = packageDeclaring('dependencies:\n  croner: any\n  "@scribe/contracts/": any\n');
    resolve(at, sdkOfCheckout());

    final Map<String, Object?> imports = importsOf(at);
    expect(imports['croner'], 'npm:croner@8', reason: 'a registry pin did not survive');
    expect(
      imports['@scribe/contracts/'],
      Uri.directory(p.join(checkout.path, 'engine', 'contracts')).toString(),
      reason: 'a path of the checkout was carried over as it was written, so it means nothing here',
    );
  });

  resolving('what the checkout pins and the package never named is out of reach', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    final Map<String, Object?> imports = importsOf(created.directory);
    expect(imports.containsKey('croner'), isFalse, reason: 'a package reaches what it never declared');
    expect(imports.containsKey('@scribe/contracts/'), isFalse, reason: 'a package reaches what it never declared');
  });

  resolving('a package reaches its own files under the name it declared', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(importsOf(created.directory)['@scribe/notifications/'], contains('notifications'));
  });

  resolving('what was resolved is written where git ignores it', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(Directory(p.join(created.directory, kResolutionDirectory)).existsSync(), isTrue);
    expect(
      File(p.join(created.directory, 'deno.json')).existsSync(),
      isFalse,
      reason: 'the runtime name leaked into the package',
    );
    expect(File(p.join(created.directory, '.gitignore')).readAsStringSync(), contains('$kResolutionDirectory/'));
  });

  resolving('a directory that is not a package is refused before anything is written', () {
    expect(() => resolve(root.path, sdkOfCheckout()), throwsA(isA<ToolExit>()));
    expect(Directory(p.join(root.path, kResolutionDirectory)).existsSync(), isFalse);
  });

  resolving('a checkout the package does not accept is refused before anything is written', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    File(
      p.join(created.directory, kManifestFile),
    ).writeAsStringSync('name: notifications\nversion: 1.0.0\n\nenvironment:\n  scribe: "^2.0.0"\n');

    expect(() => resolve(created.directory, sdkOfCheckout()), throwsA(isA<ToolExit>()));
    expect(
      Directory(p.join(created.directory, kResolutionDirectory)).existsSync(),
      isFalse,
      reason: 'a refused checkout still left a resolution behind',
    );
  });

  resolving('the refusal names both the constraint and what the checkout publishes', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    File(
      p.join(created.directory, kManifestFile),
    ).writeAsStringSync('name: notifications\nversion: 1.0.0\n\nenvironment:\n  scribe: "^2.0.0"\n');

    expect(
      () => resolve(created.directory, sdkOfCheckout()),
      throwsA(
        isA<ToolExit>().having(
          (ToolExit error) => error.message,
          'message',
          allOf(contains('^2.0.0'), contains('3.0.1')),
        ),
      ),
    );
  });

  resolving('what we write says what was resolved, in our own words', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());
    final Map<String, Object?> written = resolutionOf(created.directory);

    expect(written['package'], 'notifications');
    expect(written['entry'], 'lib/notifications.ts');
    expect(written[kEnvironmentKey], containsPair('version', '3.0.1'));
    expect(written[kEnvironmentKey], containsPair('root', checkout.path));
  });

  resolving('nothing the runtime spells reaches what we write', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());
    final Map<String, Object?> written = resolutionOf(created.directory);

    expect(written.containsKey('imports'), isFalse, reason: "the runtime's word for it came back");
    expect(written.containsKey('lock'), isFalse, reason: 'a lock the runtime names itself was named again');
  });

  resolving('what the runtime is handed is built beside it, under its own name', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    final Resolution resolution = resolve(created.directory, sdkOfCheckout());

    expect(File(resolution.runtimeConfig).existsSync(), isTrue, reason: 'the runtime was handed nothing');
    expect(runtimeConfigOf(created.directory).keys, <String>['imports']);
    expect(
      runtimeConfigOf(created.directory)['imports'],
      importsOf(created.directory),
      reason: 'the two documents disagree on what the package reaches',
    );
  });

  resolving('the package holds what we decided, and nothing else', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(
      Directory(
        p.join(created.directory, kResolutionDirectory),
      ).listSync().map((FileSystemEntity entry) => p.basename(entry.path)).toList(),
      <String>[kResolutionFile],
      reason: 'something else was left beside what we write',
    );
  });

  resolving('resolving points the editor at what it just wrote', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    final File settings = File(p.join(created.directory, kEditorDirectory, kEditorSettingsFile));
    final Map<String, Object?> held = jsonDecode(settings.readAsStringSync()) as Map<String, Object?>;

    expect(held[kEditorEnableSetting], isTrue);
    expect(held[kEditorConfigSetting], p.join(runtimeHomeOf(created.directory), kRuntimeConfigFile));
  });

  resolving('resolving keeps whatever else the editor settings held', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    File(p.join(created.directory, kEditorDirectory, kEditorSettingsFile))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"editor.rulers": [120], "deno.enable": false}\n');

    resolve(created.directory, sdkOfCheckout());

    final Map<String, Object?> held =
        jsonDecode(File(p.join(created.directory, kEditorDirectory, kEditorSettingsFile)).readAsStringSync())
            as Map<String, Object?>;

    expect(held['editor.rulers'], <int>[120], reason: 'a setting nobody asked about was dropped');
    expect(held[kEditorEnableSetting], isTrue, reason: 'the server was left off');
  });

  resolving('the editor settings are ignored by git, like everything else resolving writes', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());

    expect(File(p.join(created.directory, '.gitignore')).readAsStringSync(), contains('$kEditorDirectory/'));
  });

  resolving('a fresh package accepts the checkout that wrote it', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());

    expect(resolve(created.directory, sdkOfCheckout()).sdk.version, '3.0.1');
  });

  resolving('a package nobody resolved has to be resolved', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());

    expect(isResolved(created.directory, sdkOfCheckout()), isFalse);
  });

  resolving('a package resolved against this checkout does not have to be again', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(isResolved(created.directory, sdkOfCheckout()), isTrue);
  });

  resolving('a package resolved against another version has to be resolved again', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());
    File(
      p.join(created.directory, kResolutionDirectory, kResolutionFile),
    ).writeAsStringSync('{"$kEnvironmentKey":{"version":"2.0.0"}}\n');

    expect(isResolved(created.directory, sdkOfCheckout()), isFalse);
  });

  resolving('a resolution nobody can read has to be written again', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());
    File(p.join(created.directory, kResolutionDirectory, kResolutionFile)).writeAsStringSync('half a file');

    expect(isResolved(created.directory, sdkOfCheckout()), isFalse);
  });

  group('what a package reaches is what it declared', () {
    resolving('a package it depends on is reached under its own name', () {
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['@scribe/audiences'],
        Uri.file(p.join(root.path, 'audiences', 'lib', 'audiences.ts')).toString(),
      );
      expect(
        importsOf(at)['@scribe/audiences/testing'],
        Uri.file(p.join(root.path, 'audiences', 'tests', 'testing', 'testing.ts')).toString(),
      );
      expect(
        importsOf(at)['@scribe/audiences/'],
        isNull,
        reason: 'a specifier ending in a slash would let any file under the package be imported',
      );
    });

    resolving('what its dependency depends on is reached too', () {
      packageDeclaring('dependencies:\n', name: 'sessions');
      packageDeclaring('dependencies:\n  sessions: ^1.0.0\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/sessions'], isNotNull, reason: 'a dependency of a dependency was left out');
    });

    resolving('a package the checkout carries answers when nothing sits beside the one resolved', () {
      carriedByCheckout('audiences', 'dependencies:\n');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['@scribe/audiences'],
        Uri.file(p.join(checkout.path, kPackagesDirectory, 'audiences', 'lib', 'audiences.ts')).toString(),
      );
    });

    resolving('a package beside the one resolved wins over the copy the checkout carries', () {
      carriedByCheckout('audiences', 'dependencies:\n', version: '1.5.0');
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['@scribe/audiences'],
        Uri.file(p.join(root.path, 'audiences', 'lib', 'audiences.ts')).toString(),
        reason: 'the copy the checkout was last given won over the tree being edited',
      );
    });

    resolving('a directory whose manifest calls itself something else does not answer for the name', () {
      packageAt(root.path, 'audiences', 'dependencies:\n');
      File(p.join(root.path, 'audiences', kManifestFile)).writeAsStringSync(
        'name: sessions\nversion: 1.0.0\n\nenvironment:\n  $kEnvironmentKey: "^3.0.0"\n\ndependencies:\n',
      );
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      expect(() => resolve(at, sdkOfCheckout()), refuses(contains('audiences')));
    });

    resolving('two packages that depend on each other resolve rather than running forever', () {
      packageDeclaring('dependencies:\n  notifications: ^1.0.0\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
    });

    resolving('what a package needs to run its own suite is reached', () {
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n\ndev_dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
    });

    resolving('what a dependency needed to run its suite does not travel', () {
      packageDeclaring('dependencies:\n', name: 'sessions');
      packageDeclaring('dependencies:\n\ndev_dependencies:\n  sessions: ^1.0.0\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at).containsKey('@scribe/sessions'),
        isFalse,
        reason: "a consumer was handed what somebody else's suite needed",
      );
    });

    resolving('a specifier a dependency declared is in the map, not only the ones this package wrote', () {
      packageDeclaring('dependencies:\n  croner: any\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['croner'],
        'npm:croner@8',
        reason: 'a file of the dependency is compiled with the package that reached it',
      );
    });
  });

  group('what cannot be answered is reported, and nothing is written', () {
    resolving('a package nobody wrote', () {
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      expect(() => resolve(at, sdkOfCheckout()), refuses(allOf(contains('audiences'), contains(kPackagesDirectory))));
      expect(Directory(p.join(at, kResolutionDirectory)).existsSync(), isFalse);
    });

    resolving('a package whose version the constraint refuses', () {
      packageAt(root.path, 'audiences', 'dependencies:\n', version: '2.0.0');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      expect(() => resolve(at, sdkOfCheckout()), refuses(allOf(contains('^1.0.0'), contains('2.0.0'))));
    });

    resolving('a specifier the checkout does not pin', () {
      final String at = packageDeclaring('dependencies:\n  ioredis: any\n');

      expect(() => resolve(at, sdkOfCheckout()), refuses(allOf(contains('ioredis'), contains(kSdkImportMapFile))));
      expect(Directory(p.join(at, kResolutionDirectory)).existsSync(), isFalse);
    });

    resolving('everything that could not be answered, in one refusal', () {
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n  ioredis: any\n');

      expect(
        () => resolve(at, sdkOfCheckout()),
        refuses(allOf(contains('2 things'), contains('audiences'), contains('ioredis'))),
      );
    });
  });
}
