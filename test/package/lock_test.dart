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

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/package/lock.dart';
import 'package:test/test.dart';

const LocalFileSystem _fs = LocalFileSystem();

Matcher throwsToolExit(String saying) =>
    throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

void main() {
  const String where = 'auth/package.lock';

  test('a lock reads back what it rendered', () {
    const PackageLock written = PackageLock(
      scribe: '1.0.0',
      packages: <LockedPackage>[
        LockedPackage(name: 'foundation', version: '1.2.0', source: LockSource.sdk),
        LockedPackage(name: 'notifications', version: '0.4.0', source: LockSource.workspace),
      ],
    );

    final PackageLock read = PackageLock.parse(written.render(), where);

    expect(read.scribe, '1.0.0');
    expect(read.byName('foundation')?.version, '1.2.0');
    expect(read.byName('foundation')?.source, LockSource.sdk);
    expect(read.byName('notifications')?.version, '0.4.0');
    expect(read.byName('notifications')?.source, LockSource.workspace);
  });

  test('a lock with no packages renders and reads back empty', () {
    const PackageLock written = PackageLock(scribe: '1.0.0', packages: <LockedPackage>[]);

    final PackageLock read = PackageLock.parse(written.render(), where);

    expect(read.packages, isEmpty);
  });

  test('a package sitting at a path locks the source that says so', () {
    const PackageLock written = PackageLock(
      scribe: '1.0.0',
      packages: <LockedPackage>[LockedPackage(name: 'billing', version: '0.1.0', source: LockSource.path)],
    );

    final PackageLock read = PackageLock.parse(written.render(), where);

    expect(read.byName('billing')?.source, LockSource.path);
  });

  test('a lock without "scribe:" is refused', () {
    expect(() => PackageLock.parse('packages:\n', where), throwsToolExit('has no "scribe:"'));
  });

  test('a lock naming something other than scribe or packages is refused', () {
    expect(() => PackageLock.parse('scribe: 1.0.0\nnotes: keep out\n', where), throwsToolExit('carries "notes"'));
  });

  test('a locked package without a version is refused', () {
    expect(
      () => PackageLock.parse('scribe: 1.0.0\npackages:\n  foundation:\n    source: sdk\n', where),
      throwsToolExit('has no "version:"'),
    );
  });

  test('a locked package without a source is refused', () {
    expect(
      () => PackageLock.parse('scribe: 1.0.0\npackages:\n  foundation:\n    version: 1.0.0\n', where),
      throwsToolExit('has no "source:"'),
    );
  });

  test('a locked package naming a source that does not exist is refused', () {
    expect(
      () => PackageLock.parse(
        'scribe: 1.0.0\npackages:\n  foundation:\n    version: 1.0.0\n    source: registry\n',
        where,
      ),
      throwsToolExit('names a source of "registry"'),
    );
  });

  test('reading a lock that is not there answers null', () {
    final Directory root = _fs.systemTempDirectory.createTempSync('scribe_lock_');
    addTearDown(() => root.deleteSync(recursive: true));

    expect(PackageLock.readFrom(_fs.file(p.join(root.path, 'package.lock'))), isNull);
  });

  test('writing a lock creates the directory it is asked to sit in', () {
    final Directory root = _fs.systemTempDirectory.createTempSync('scribe_lock_');
    addTearDown(() => root.deleteSync(recursive: true));
    final File file = _fs.file(p.join(root.path, 'nested', 'package.lock'));

    const PackageLock(
      scribe: '1.0.0',
      packages: <LockedPackage>[LockedPackage(name: 'foundation', version: '1.0.0', source: LockSource.sdk)],
    ).writeTo(file);

    expect(PackageLock.readFrom(file)?.byName('foundation')?.version, '1.0.0');
  });
}
