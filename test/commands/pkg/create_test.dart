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

import 'pkg_source.dart';

void main() {
  late PkgHarness machine;

  setUp(() => machine = PkgHarness());

  test('creating a package leaves the status of a run that worked', () async {
    expect(await machine.run(<String>['pkg', 'create', 'audiences', '--in', kWorkDirectory]), 0);
    expect(machine.fs.directory('$kWorkDirectory/audiences').existsSync(), isTrue, reason: 'nothing was written');
  });

  test('creating a package says what it wrote', () async {
    await machine.run(<String>['pkg', 'create', 'audiences', '--in', kWorkDirectory]);

    expect(machine.logger.statusText, contains('package.yaml'));
    expect(machine.logger.statusText, contains('lib/audiences.ts'));
    expect(machine.logger.statusText, contains('tests/e2e/.gitkeep'));
  });

  test('the manifest is written against the checkout that wrote it', () async {
    await machine.run(<String>['pkg', 'create', 'audiences', '--in', kWorkDirectory]);

    expect(machine.fs.file('$kWorkDirectory/audiences/package.yaml').readAsStringSync(), contains('"^3.0.1"'));
  });

  test('a name the rule refuses leaves the status of a fault', () async {
    expect(await machine.run(<String>['pkg', 'create', 'Audiences', '--in', kWorkDirectory]), 1);
    expect(machine.logger.errorText, contains('cannot name a package'));
  });

  test('creating over something that is already there refuses rather than writing into it', () async {
    machine.fs.directory('$kWorkDirectory/audiences').createSync(recursive: true);

    expect(await machine.run(<String>['pkg', 'create', 'audiences', '--in', kWorkDirectory]), 1);
    expect(machine.logger.errorText, contains('already exists'));
  });

  test('creating without a name says what the name becomes', () async {
    expect(await machine.run(<String>['pkg', 'create', '--in', kWorkDirectory]), 64);
    expect(machine.logger.errorText, contains('needs a <name>'));
    expect(machine.logger.errorText, contains('becomes the directory'));
  });
}
