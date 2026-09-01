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
import 'package:scribe_tools/src/package/lock.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:test/test.dart';

import 'git_repo_source.dart';
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

  PackageLock lockOf(String package) {
    final String path = p.join(package, kPackageLockFile);
    return PackageLock.parse(File(path).readAsStringSync(), path);
  }

  String packageAt(String parent, String name, String blocks, {String version = '1.0.0'}) {
    final CreatedPackage created = createPackage(parent, name, sdkOfCheckout());
    File(
      p.join(created.directory, kManifestFile),
    ).writeAsStringSync('name: $name\nversion: $version\n\nenvironment:\n  $kEnvironmentKey: "^3.0.0"\n\n$blocks');

    return created.directory;
  }

  String packageDeclaring(String blocks, {String name = 'notifications'}) => packageAt(root.path, name, blocks);

  void importing(String at, String name, String specifier) =>
      File(p.join(at, 'lib', '$name.ts')).writeAsStringSync('\nimport "$specifier";\n', mode: FileMode.append);

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

  resolving('a package reaches its own subjects, one door per file in lib/', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    File(p.join(created.directory, 'lib', 'digest.ts')).writeAsStringSync('export {};\n');
    resolve(created.directory, sdkOfCheckout());

    expect(
      importsOf(created.directory)['@scribe/notifications/digest'],
      Uri.file(p.join(created.directory, 'lib', 'digest.ts')).toString(),
      reason: 'a subject door the package publishes was left out',
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

  resolving('what the checkout pins answers the specifiers the package imports', () {
    final String at = packageDeclaring('dependencies:\n');
    importing(at, 'notifications', 'croner');
    resolve(at, sdkOfCheckout());

    expect(importsOf(at)['croner'], 'npm:croner@8', reason: 'a registry pin did not survive');
  });

  resolving('a framework surface is reachable whether or not a package imports it', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(
      importsOf(created.directory)['@scribe/contracts/'],
      '${p.join(checkout.path, 'engine', 'contracts')}/',
      reason: 'a layer the checkout carries was held against what the package happened to import',
    );
  });

  resolving('what the checkout pins and the package never imports is out of reach', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    resolve(created.directory, sdkOfCheckout());

    expect(
      importsOf(created.directory).containsKey('croner'),
      isFalse,
      reason: 'a package reaches what it never imported',
    );
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
      reason: 'nothing named after the runtime is written; deno reads what we hand it directly',
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

  resolving('resolving hands deno the map directly, writing no file for it', () {
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    final Resolution resolution = resolve(created.directory, sdkOfCheckout());

    expect(resolution.importMap, startsWith('data:application/json;base64,'));
    final String decoded = utf8.decode(base64Decode(resolution.importMap.split(',').last));
    expect(jsonDecode(decoded), <String, Object?>{'imports': resolution.imports});
    expect(File(p.join(created.directory, 'deno.json')).existsSync(), isFalse);
    expect(
      File(p.join(root.path, 'deno.json')).existsSync(),
      isFalse,
      reason: 'a map was written that every package here would share',
    );
  });

  resolving('a package beside the one resolved, but not depended on, stays out of its map', () {
    createPackage(root.path, 'audiences', sdkOfCheckout());
    final CreatedPackage created = createPackage(root.path, 'notifications', sdkOfCheckout());
    final Resolution resolution = resolve(created.directory, sdkOfCheckout());

    expect(resolution.imports['@scribe/notifications'], isNotNull);
    expect(
      resolution.imports.containsKey('@scribe/audiences'),
      isFalse,
      reason:
          'a neighbour nothing depends on has no reason to be reachable, the way flutter/packages '
          'never links one package to a sibling it never declared',
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

  resolving('resolving again reflects only what the manifest still names', () {
    createPackage(root.path, 'audiences', sdkOfCheckout());
    final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n', name: 'notifications');
    expect(resolve(at, sdkOfCheckout()).imports.containsKey('@scribe/audiences'), isTrue);

    File(
      p.join(at, kManifestFile),
    ).writeAsStringSync('name: notifications\nversion: 1.0.0\n\nenvironment:\n  $kEnvironmentKey: "^3.0.0"\n');

    expect(
      resolve(at, sdkOfCheckout()).imports.containsKey('@scribe/audiences'),
      isFalse,
      reason: 'the map kept a dependency the manifest no longer names',
    );
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

    resolving('a subject door of a dependency reaches the file that backs it', () {
      final String reached = packageDeclaring('dependencies:\n', name: 'audiences');
      File(p.join(reached, 'lib', 'members.ts')).writeAsStringSync('export {};\n');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['@scribe/audiences/members'],
        Uri.file(p.join(root.path, 'audiences', 'lib', 'members.ts')).toString(),
        reason: 'a dependency that carries no deno.json still publishes a door per lib/ file',
      );
      expect(
        importsOf(at).containsKey('@scribe/audiences/audiences'),
        isFalse,
        reason: 'the entry was handed over a second time as a subject door',
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

    resolving('a specifier a dependency imports is in the map, not only the ones this package wrote', () {
      final String reached = packageDeclaring('dependencies:\n', name: 'audiences');
      importing(reached, 'audiences', 'croner');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(
        importsOf(at)['croner'],
        'npm:croner@8',
        reason: 'a file of the dependency is compiled with the package that reached it',
      );
    });
  });

  group('the versions resolving found are frozen in package.lock', () {
    resolving('a lock names the framework version resolving ran against', () {
      final String at = packageDeclaring('dependencies:\n');

      resolve(at, sdkOfCheckout());

      expect(lockOf(at).scribe, sdkOfCheckout().version);
    });

    resolving('a dependency found beside the package is locked as a workspace copy', () {
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      final LockedPackage? locked = lockOf(at).byName('audiences');
      expect(locked?.version, '1.0.0');
      expect(locked?.source, LockSource.workspace);
    });

    resolving('a dependency the checkout carries is locked as an sdk copy', () {
      carriedByCheckout('audiences', 'dependencies:\n', version: '1.5.0');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      final LockedPackage? locked = lockOf(at).byName('audiences');
      expect(locked?.version, '1.5.0');
      expect(locked?.source, LockSource.sdk);
    });

    resolving('a dependency of a dependency is locked too', () {
      packageDeclaring('dependencies:\n', name: 'sessions');
      packageDeclaring('dependencies:\n  sessions: ^1.0.0\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');

      resolve(at, sdkOfCheckout());

      expect(lockOf(at).byName('sessions')?.version, '1.0.0');
    });

    resolving('the package being resolved does not lock itself', () {
      final String at = packageDeclaring('dependencies:\n', name: 'audiences');

      resolve(at, sdkOfCheckout());

      expect(lockOf(at).byName('audiences'), isNull);
    });

    resolving('resolving again after a version moved rewrites the lock to match', () {
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');
      resolve(at, sdkOfCheckout());
      expect(lockOf(at).byName('audiences')?.version, '1.0.0');

      Directory(p.join(root.path, 'audiences')).deleteSync(recursive: true);
      packageAt(root.path, 'audiences', 'dependencies:\n', version: '1.4.0');
      resolve(at, sdkOfCheckout());

      expect(lockOf(at).byName('audiences')?.version, '1.4.0');
    });
  });

  group('a path: or a git: dependency is resolved from where it names, not searched for', () {
    resolving('a path: dependency is resolved against the package that wrote it, not the project', () {
      packageDeclaring('dependencies:\n', name: 'audiences');
      final String at = packageDeclaring('dependencies:\n  audiences:\n    path: ../audiences\n');

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
      expect(lockOf(at).byName('audiences')?.source, LockSource.path);
    });

    resolving('a path: dependency whose manifest calls itself something else is refused', () {
      packageAt(root.path, 'audiences', 'dependencies:\n');
      File(p.join(root.path, 'audiences', kManifestFile)).writeAsStringSync(
        'name: sessions\nversion: 1.0.0\n\nenvironment:\n  $kEnvironmentKey: "^3.0.0"\n\ndependencies:\n',
      );
      final String at = packageDeclaring('dependencies:\n  audiences:\n    path: ../audiences\n');

      expect(() => resolve(at, sdkOfCheckout()), refuses(contains('audiences')));
    });

    resolving('a git: dependency is cloned and its commit locked', () {
      final Directory remote = Directory.systemTemp.createTempSync('scribe_git_remote_');
      addTearDown(() => remote.deleteSync(recursive: true));
      final CreatedPackage created = createPackage(remote.path, 'audiences', sdkOfCheckout());
      final String commit = initGitRepo(created.directory);

      final String at = packageDeclaring(
        'dependencies:\n  audiences:\n    git:\n      url: ${created.directory}\n      ref: trunk\n',
      );

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
      final LockedPackage? locked = lockOf(at).byName('audiences');
      expect(locked?.source, LockSource.git);
      expect(locked?.resolvedRef, commit);
    });

    resolving('a git: dependency with no ref follows the remote default branch', () {
      final Directory remote = Directory.systemTemp.createTempSync('scribe_git_remote_');
      addTearDown(() => remote.deleteSync(recursive: true));
      final CreatedPackage created = createPackage(remote.path, 'audiences', sdkOfCheckout());
      initGitRepo(created.directory);

      final String at = packageDeclaring('dependencies:\n  audiences:\n    git:\n      url: ${created.directory}\n');

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
    });

    resolving('a git: dependency with a path: reads the package from that subdirectory', () {
      final Directory remote = Directory.systemTemp.createTempSync('scribe_git_remote_');
      addTearDown(() => remote.deleteSync(recursive: true));
      createPackage(remote.path, 'audiences', sdkOfCheckout());
      initGitRepo(remote.path);

      final String at = packageDeclaring(
        'dependencies:\n  audiences:\n    git:\n      url: ${remote.path}\n      ref: trunk\n      path: audiences\n',
      );

      resolve(at, sdkOfCheckout());

      expect(importsOf(at)['@scribe/audiences'], isNotNull);
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
      final String at = packageDeclaring('dependencies:\n');
      importing(at, 'notifications', 'left-pad');

      expect(() => resolve(at, sdkOfCheckout()), refuses(allOf(contains('left-pad'), contains(kSdkImportMapFile))));
      expect(Directory(p.join(at, kResolutionDirectory)).existsSync(), isFalse);
    });

    resolving('everything that could not be answered, in one refusal', () {
      final String at = packageDeclaring('dependencies:\n  audiences: ^1.0.0\n');
      importing(at, 'notifications', 'left-pad');

      expect(
        () => resolve(at, sdkOfCheckout()),
        refuses(allOf(contains('2 things'), contains('audiences'), contains('left-pad'))),
      );
    });
  });
}
