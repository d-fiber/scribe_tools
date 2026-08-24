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

import 'pkg_source.dart';

void main() {
  late PkgHarness machine;

  setUp(() => machine = PkgHarness());

  Future<String> created(String name) async {
    await machine.run(<String>['pkg', 'create', name, '--in', kWorkDirectory]);
    return '$kWorkDirectory/$name';
  }

  Map<String, Object?> resolutionOf(String package) =>
      jsonDecode(machine.fs.file('$package/$kResolutionDirectory/$kResolutionFile').readAsStringSync())
          as Map<String, Object?>;

  test('resolving a package leaves the status of a run that worked', () async {
    final String package = await created('notifications');

    expect(await machine.run(<String>['pkg', 'get', package]), 0);
    expect(
      machine.fs.file('$package/$kResolutionDirectory/$kResolutionFile').existsSync(),
      isTrue,
      reason: 'nothing was written for the tools to read',
    );
  });

  test('resolving says which checkout it resolved against, and what it wrote', () async {
    final String package = await created('notifications');
    await machine.run(<String>['pkg', 'get', package]);

    expect(machine.logger.statusText, contains('3.0.1'));
    expect(machine.logger.statusText, contains('@scribe/alchemy'));
    expect(machine.logger.statusText, contains(kResolutionFile));
  });

  test('resolving writes down which checkout it used, so a later run can tell', () async {
    final String package = await created('notifications');
    await machine.run(<String>['pkg', 'get', package]);

    expect(resolutionOf(package)[kEnvironmentKey], containsPair('version', '3.0.1'));
  });

  test('what the runtime is handed is built outside the package, under the home directory', () async {
    final String package = await created('notifications');
    await machine.run(<String>['pkg', 'get', package]);

    expect(machine.logger.statusText, contains('$kHomeDirectory/$kToolDirectory/$kRuntimesDirectory'));
    expect(
      machine.fs.file('$package/$kRuntimeConfigFile').existsSync(),
      isFalse,
      reason: "the runtime's name leaked into the package",
    );
  });

  test('a directory that is not a package leaves the status of a fault', () async {
    machine.fs.directory('$kWorkDirectory/nothing').createSync(recursive: true);

    expect(await machine.run(<String>['pkg', 'get', '$kWorkDirectory/nothing']), 1);
    expect(machine.logger.errorText, contains('is not a package'));
  });

  test('a checkout the package does not accept is refused, naming both versions', () async {
    final String package = await created('notifications');
    machine.writeCheckout(version: '4.0.0');

    expect(await machine.run(<String>['pkg', 'get', package]), 1);
    expect(machine.logger.errorText, contains('^3.0.1'));
    expect(machine.logger.errorText, contains('4.0.0'));
  });

  test('no checkout anywhere leaves the status of a fault, and says how to name one', () async {
    final String package = await created('notifications');
    machine.fs.directory('$kCheckoutDirectory/host').deleteSync(recursive: true);

    expect(await machine.run(<String>['pkg', 'get', package]), 1);
    expect(machine.logger.errorText, contains(kSdkRootVariable));
  });

  test('a package with no tests directory is refused before anything is resolved', () async {
    final String package = await created('notifications');
    machine.fs.directory('$package/tests').deleteSync(recursive: true);

    expect(await machine.run(<String>['pkg', 'test', package]), 1);
    expect(machine.logger.errorText, contains('does not hold together'));
    expect(machine.logger.errorText, contains('a package nobody tested is not one'));
  });

  test('a package whose tests went after it was resolved is refused by the runner', () async {
    final String package = await created('notifications');
    await machine.run(<String>['pkg', 'get', package]);
    machine.fs.directory('$package/tests').deleteSync(recursive: true);

    expect(await machine.run(<String>['pkg', 'test', package]), 1);
    expect(machine.logger.errorText, contains('nothing to run'));
  });

  test('running the tests hands the runtime the configuration built outside the package', () async {
    final String package = await created('notifications');

    expect(await machine.run(<String>['pkg', 'test', package]), 0);
    expect(machine.processRunner.commands.single, containsAll(<String>['deno', 'test', 'tests']));
  });
}
