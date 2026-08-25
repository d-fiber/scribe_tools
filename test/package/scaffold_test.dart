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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/package/checks.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  const Sdk sdk = Sdk(root: '/checkout', version: '3.0.1');

  setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a fresh package passes the checks it will be held to', () {
    createPackage(root.path, 'audiences', sdk);

    expect(check(discover(<String>[root.path])), isEmpty, reason: 'what was written is refused by the checks');
  });

  test('a fresh package carries the layout and nothing more', () {
    final CreatedPackage created = createPackage(root.path, 'audiences', sdk);

    expect(created.files..sort(), <String>[
      '.gitignore',
      'lib/audiences.ts',
      'lib/src/.gitkeep',
      'package.yaml',
      'tests/audiences.test.ts',
      'tests/e2e/.gitkeep',
    ]);
  });

  test('a fresh package names itself after its directory', () {
    createPackage(root.path, 'audiences', sdk);
    final List<DiscoveredPackage> found = discover(<String>[root.path]);

    expect(found.single.name, 'audiences');
    expect(found.single.manifest.version, '1.0.0');
  });

  test('the ignore file keeps what the tools generate out', () {
    final CreatedPackage created = createPackage(root.path, 'audiences', sdk);
    final String ignored = File(p.join(created.directory, '.gitignore')).readAsStringSync();

    expect(ignored, contains('tests/e2e/.generated/'));
    expect(ignored, contains('.scribe/'));
  });

  test('a fresh package hands the stack nothing, and carries the block to say what it could', () {
    final CreatedPackage created = createPackage(root.path, 'audiences', sdk);
    final String manifest = File(p.join(created.directory, 'package.yaml')).readAsStringSync();
    final List<DiscoveredPackage> found = discover(<String>[root.path]);

    expect(found.single.manifest.artefacts.isEmpty, isTrue);
    expect(manifest, contains('# scribe:'));
    expect(manifest, contains('#     init: ./db/init/'));
    expect(manifest, contains('#     - ./ops/database/'));
  });

  test('a name that cannot be a package cannot be created', () {
    expect(() => createPackage(root.path, 'Audiences', sdk), throwsA(isA<ToolExit>()));
  });

  test('a package is never written over something already there', () {
    createPackage(root.path, 'audiences', sdk);

    expect(() => createPackage(root.path, 'audiences', sdk), throwsA(isA<ToolExit>()));
  });

  test('the manifest it writes carries both dependency blocks even when empty', () {
    createPackage(root.path, 'audiences', sdk);
    final String manifest = File(p.join(root.path, 'audiences', 'package.yaml')).readAsStringSync();

    expect(manifest, contains('\ndependencies:\n'), reason: 'a package that depends on nothing does not say so');
    expect(
      manifest,
      contains('\n$kDevDependenciesKey:\n'),
      reason: 'a block nothing writes is a block nobody finds',
    );
  });
}
