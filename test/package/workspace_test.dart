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
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  const Sdk sdk = Sdk(root: '/checkout', version: '3.0.1');

  setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a package is found by its manifest', () {
    createPackage(root.path, 'audiences', sdk);

    expect(discover(<String>[root.path]).single.name, 'audiences');
  });

  test('what is found comes back sorted by name', () {
    createPackage(root.path, 'storage', sdk);
    createPackage(root.path, 'audiences', sdk);
    createPackage(root.path, 'realtime', sdk);

    expect(discover(<String>[root.path]).map((DiscoveredPackage found) => found.name), <String>[
      'audiences',
      'realtime',
      'storage',
    ]);
  });

  test('a package one level down is found too', () {
    Directory(p.join(root.path, 'security')).createSync();
    createPackage(p.join(root.path, 'security'), 'auth', sdk);

    expect(discover(<String>[root.path]).single.name, 'auth');
  });

  test('the walk stops at a package instead of entering it', () {
    final CreatedPackage realtime = createPackage(root.path, 'realtime', sdk);
    createPackage(p.join(realtime.directory, 'tests'), 'audiences', sdk);

    expect(discover(<String>[root.path]).map((DiscoveredPackage found) => found.name), <String>['realtime']);
  });

  test('a root that is not there yields nothing rather than failing', () {
    expect(discover(<String>[p.join(root.path, 'nowhere')]), isEmpty);
  });

  test('a directory without a manifest is not a package', () {
    Directory(p.join(root.path, 'realtime')).createSync();

    expect(() => loadManifest(p.join(root.path, 'realtime')), throwsA(isA<ToolExit>()));
  });

  test('the entry of a package is named after it, under lib', () {
    expect(entryOf('audiences'), 'lib/audiences.ts');
  });

  test('a package is mounted under the name of its directory', () {
    final CreatedPackage created = createPackage(root.path, 'audiences', sdk);

    expect(p.basename(created.directory), discover(<String>[root.path]).single.name);
  });
}
