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
import 'package:test/test.dart';

import 'package_source.dart';

void main() {
  late PackageHarness machine;

  setUp(() => machine = PackageHarness());

  Future<String> package(String name) async {
    machine.fs.currentDirectory = machine.fs.directory(kWorkDirectory);
    await machine.run(<String>['create', name, '--package']);
    final String at = '$kWorkDirectory/$name';
    machine.fs.currentDirectory = machine.fs.directory(at);
    return at;
  }

  /// Rewrites the package at [at] to name `runtime` under `environment:`, the way `create
  /// --package` never does on its own: there is no flag for it, so a package that wants `bun`
  /// edits its own manifest the same way a person would.
  void useRuntime(String at, String runtime) {
    final File manifest = machine.fs.file('$at/package.yaml');
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceFirst('environment:\n  scribe:', 'environment:\n  runtime: $runtime\n  scribe:'),
    );
  }

  group('a single deno package', () {
    test('reports it resolved, and hands a language server projection for deno', () async {
      final String at = await package('notifications');
      await machine.run(<String>['forge']);
      machine.logger.clear();

      expect(await machine.run(<String>['editor', at, '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['command'], 'editor');
      expect(document['ok'], isTrue);
      expect(document['packages'], <Object?>[
        <String, Object?>{'directory': at, 'runtime': 'deno', 'resolved': true},
      ]);
      expect(document['conflicts'], isEmpty);
      expect(document['filesWritten'], isEmpty);

      final List<Map<String, Object?>> servers = (document['languageServers']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(servers, hasLength(1));
      expect(servers.single['runtime'], 'deno');
      expect(servers.single['extensionId'], 'denoland.vscode-deno');
      expect(servers.single['enableSettingKey'], 'deno.enable');
      expect(servers.single['configSettingKey'], 'deno.config');
      expect(servers.single['additionalSettings'], <String, Object?>{
        'deno.enablePaths': <String>[at],
      });

      final Map<String, Object?> contents = jsonDecode(servers.single['configContents']! as String) as Map<String, Object?>;
      expect((contents['imports']! as Map<String, Object?>)['@scribe/alchemy'], isNotNull);
    });
  });

  group('a package whose resolution has gone missing', () {
    test('is reported unresolved, folded in as an empty contribution, ok is false', () async {
      final String at = await package('notifications');
      machine.fs.directory('$at/.scribe').deleteSync(recursive: true);
      machine.logger.clear();

      expect(await machine.run(<String>['editor', at, '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['ok'], isFalse);
      expect(document['packages'], <Object?>[
        <String, Object?>{'directory': at, 'runtime': 'deno', 'resolved': false},
      ]);

      final List<Map<String, Object?>> servers = (document['languageServers']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(servers.single['configContents'], contains('"imports":{}'));
    });
  });

  group('a workspace holding a deno package and a bun package', () {
    test('the bun package gets a tsconfig.json and no language server entry', () async {
      final String denoAt = await package('notifications');
      await machine.run(<String>['forge']);

      final String bunAt = await package('exporter');
      useRuntime(bunAt, 'bun');
      await machine.run(<String>['forge']);

      machine.logger.clear();
      expect(await machine.run(<String>['editor', denoAt, bunAt, '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['ok'], isTrue);
      expect((document['packages']! as List<Object?>).cast<Map<String, Object?>>(), unorderedEquals(<Object?>[
        <String, Object?>{'directory': denoAt, 'runtime': 'deno', 'resolved': true},
        <String, Object?>{'directory': bunAt, 'runtime': 'bun', 'resolved': true},
      ]));

      final List<Map<String, Object?>> servers = (document['languageServers']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(servers, hasLength(1), reason: 'only deno has a language server to configure');
      expect(servers.single['runtime'], 'deno');
      expect(servers.single['additionalSettings'], <String, Object?>{
        'deno.enablePaths': <String>[denoAt],
      });

      expect(document['filesWritten'], <String>['$bunAt/tsconfig.json']);
      expect(machine.fs.file('$bunAt/tsconfig.json').existsSync(), isTrue);

      final Map<String, Object?> tsconfig =
          jsonDecode(machine.fs.file('$bunAt/tsconfig.json').readAsStringSync()) as Map<String, Object?>;
      final Map<String, Object?> paths = (tsconfig['compilerOptions']! as Map<String, Object?>)['paths']! as Map<String, Object?>;
      expect(paths['@scribe/alchemy'], isNotNull);
    });
  });

  test('no directory given is refused, naming what it needs', () async {
    expect(await machine.run(<String>['editor']), 1);
    expect(machine.logger.errorText, contains('<directory>'));
  });

  test('a directory with no package.yaml is refused', () async {
    machine.fs.directory('$kWorkDirectory/empty').createSync(recursive: true);

    expect(await machine.run(<String>['editor', '$kWorkDirectory/empty']), 1);
    expect(machine.logger.errorText, contains('carries no package.yaml'));
  });
}
