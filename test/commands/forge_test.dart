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

    test('the map a language server reads sits beside the packages, not in one', () async {
      final String at = await package('notifications');

      await machine.run(<String>['forge']);

      expect(machine.fs.file('$kWorkDirectory/$kPackagesConfigFile').existsSync(), isTrue);
      expect(
        machine.fs.file('$at/$kPackagesConfigFile').existsSync(),
        isFalse,
        reason: 'a package was made to carry a runtime config',
      );
      expect(machine.logger.statusText, contains(kPackagesConfigFile));
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
