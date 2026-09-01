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
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:test/test.dart';

import 'package_source.dart';

void main() {
  late PackageHarness machine;

  setUp(() => machine = PackageHarness());

  Future<String> package(String name) async {
    await machine.run(<String>['create', name, '--package']);
    final String at = '$kWorkDirectory/$name';
    machine.fs.currentDirectory = machine.fs.directory(at);
    return at;
  }

  Map<String, Object?> resolutionOf(String at) =>
      jsonDecode(machine.fs.file('$at/$kResolutionDirectory/$kResolutionFile').readAsStringSync())
          as Map<String, Object?>;

  group('in a package, forge resolves it against the checkout', () {
    test('it writes down what the tools read', () async {
      final String at = await package('notifications');

      expect(await machine.run(<String>['forge']), 0);
      expect(
        machine.fs.file('$at/$kResolutionDirectory/$kResolutionFile').existsSync(),
        isTrue,
        reason: 'nothing was written for the tools to read',
      );
    });

    test('it says which checkout it resolved against, and what it wrote', () async {
      await package('notifications');

      await machine.run(<String>['forge']);

      expect(machine.logger.statusText, contains('3.0.1'));
      expect(machine.logger.statusText, contains('@scribe/alchemy'));
      expect(machine.logger.statusText, contains(kResolutionFile));
    });

    test('it writes down which checkout it used, so a later run can tell', () async {
      final String at = await package('notifications');

      await machine.run(<String>['forge']);

      expect(resolutionOf(at)[kEnvironmentKey], containsPair('version', '3.0.1'));
    });

    test('nothing named after the runtime is written, in the package or beside it', () async {
      final String at = await package('notifications');

      await machine.run(<String>['forge']);

      expect(machine.fs.file('$at/deno.json').existsSync(), isFalse);
      expect(
        machine.fs.file('$kWorkDirectory/deno.json').existsSync(),
        isFalse,
        reason: 'a map was written that every package here would share',
      );
      expect(machine.logger.statusText, contains('deno.json'), reason: 'the change is explained, even unwritten');
    });

    test('a checkout the package does not accept is refused, naming both versions', () async {
      await package('notifications');
      machine.writeCheckout(version: '4.0.0');

      expect(await machine.run(<String>['forge']), 1);
      expect(machine.logger.errorText, contains('^3.0.1'));
      expect(machine.logger.errorText, contains('4.0.0'));
    });

    test('no checkout anywhere leaves the status of a fault, and says how to name one', () async {
      await package('notifications');
      machine.fs.directory('$kCheckoutDirectory/engine').deleteSync(recursive: true);

      expect(await machine.run(<String>['forge']), 1);
      expect(machine.logger.errorText, contains(kSdkRootVariable));
    });

    test('--dry-run is a project-only flag and is refused here', () async {
      await package('notifications');

      expect(await machine.run(<String>['forge', '--dry-run']), 64);
      expect(machine.logger.errorText, contains('only means something in a project'));
    });

    test('--machine prints one line of JSON naming the sdk, the imports and the two files', () async {
      final String at = await package('notifications');
      machine.logger.clear();

      expect(await machine.run(<String>['forge', '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['command'], 'forge');
      expect(document['kind'], 'package');
      expect(document['ok'], isTrue);
      expect(document['sdk'], <String, Object?>{'version': '3.0.1', 'root': kCheckoutDirectory});
      expect(document['resolutionFile'], '$at/$kResolutionDirectory/$kResolutionFile');
      expect(document['lockFile'], '$at/$kPackageLockFile');
      expect((document['imports']! as Map<String, Object?>)['@scribe/alchemy'], isNotNull);
      expect(machine.logger.statusText.trim().split('\n'), hasLength(1), reason: '--machine prints exactly one line');
    });

    test('--watch watches lib/ and package.yaml, and resolves again on a change', () async {
      final String at = await package('notifications');

      final Future<int> run = machine.run(<String>['forge', '--watch']);
      while (machine.watcher.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(machine.watcher.requests.single.map((FileSystemEntity entity) => entity.path), <String>[
        '$at/lib',
        '$at/$kManifestFile',
      ]);

      machine.watcher.change();
      await Future<void>.delayed(Duration.zero);
      await machine.watcher.stop();

      expect(await run, 0);
      expect(
        'Resolved against scribe 3.0.1 in $kCheckoutDirectory'.allMatches(machine.logger.statusText).length,
        2,
        reason: 'once for the run before the watch, once for the run the change caused',
      );
    });
  });

  group('forge run where it is neither a project nor a package', () {
    test('an empty directory is refused, naming both roots it looks for', () async {
      machine.fs.currentDirectory = machine.fs.directory('$kWorkDirectory/empty')..createSync(recursive: true);

      expect(await machine.run(<String>['forge']), 1);
      expect(machine.logger.errorText, contains('config.yaml'));
      expect(machine.logger.errorText, contains('package.yaml'));
    });

    test('a directory with only a config.yaml is a project missing its entries', () async {
      const String root = '$kWorkDirectory/half';
      machine.fs.file('$root/config.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: half\n');
      machine.fs.currentDirectory = machine.fs.directory(root);

      expect(await machine.run(<String>['forge']), 1);
      expect(machine.logger.errorText, contains('lib/'));
    });
  });
}
