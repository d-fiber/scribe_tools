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

import 'package:test/test.dart';

import 'package_source.dart';

void main() {
  late PackageHarness machine;

  setUp(() => machine = PackageHarness());

  Future<void> create(String name) => machine.run(<String>['create', name, '--package', '--in', kWorkDirectory]);

  test('a sound package leaves the status of a run that worked', () async {
    await create('audiences');

    expect(await machine.run(<String>['analyze', kWorkDirectory]), 0);
    expect(machine.logger.statusText, contains('1 package, nothing to report.'));
  });

  test('a package missing a piece of the layout leaves the status of a fault', () async {
    await create('audiences');
    machine.fs.file('$kWorkDirectory/audiences/.gitignore').deleteSync();

    expect(await machine.run(<String>['analyze', kWorkDirectory]), 1);
    expect(machine.logger.errorText, contains('would be committed with the source'));
    expect(machine.logger.errorText, contains('1 problem across 1 package.'));
  });

  test('every package under the root is read, not only the first', () async {
    await create('audiences');
    await create('storage');

    expect(await machine.run(<String>['analyze', kWorkDirectory]), 0);
    expect(machine.logger.statusText, contains('2 packages, nothing to report.'));
  });

  test('analysing where there is no package says so', () async {
    expect(await machine.run(<String>['analyze', kWorkDirectory]), 1);
    expect(machine.logger.errorText, contains('No package under'));
  });
}
