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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/dependency_source.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:test/test.dart';

Matcher throwsToolExit(String saying) =>
    throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

void main() {
  const String where = 'audiences/package.yaml';
  const String environment = 'environment:\n  scribe: "^3.0.0"\n';

  test('a manifest reads its five keys', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\ndescription: Broadcasts a row.\nversion: 1.2.0\n\n$environment\ndependencies:\n  audiences: "^1.0.0"\n',
      where,
    );

    expect(manifest.name, 'realtime');
    expect(manifest.description, 'Broadcasts a row.');
    expect(manifest.version, '1.2.0');
    expect(manifest.scribe, '^3.0.0');
    expect((manifest.dependencies['audiences'] as SdkSource?)?.constraint, '^1.0.0');
  });

  test('a manifest without a description takes the one that asks for one', () {
    final Manifest manifest = Manifest.parse('name: audiences\nversion: 1.0.0\n$environment', where);

    expect(manifest.description, kDefaultDescription);
  });

  test('a manifest without a name is refused', () {
    expect(() => Manifest.parse('version: 1.0.0\n', where), throwsToolExit('has no "name:"'));
  });

  test('a manifest without a version is refused', () {
    expect(() => Manifest.parse('name: audiences\n', where), throwsToolExit('has no "version:"'));
  });

  test('a manifest that names no framework is refused, and shows the block to write', () {
    expect(() => Manifest.parse('name: audiences\nversion: 1.0.0\n', where), throwsToolExit('has no "environment:"'));
  });

  test('a framework constraint that is not one is refused', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: 1.0.0\nenvironment:\n  scribe: "3.x"\n', where),
      throwsToolExit('is not a constraint'),
    );
  });

  test('a key beside the framework in the environment block is refused', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: 1.0.0\nenvironment:\n  deno: "^2.0.0"\n', where),
      throwsToolExit('"environment.deno:", which means nothing'),
    );
  });

  test('an environment block that names nothing is refused', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: 1.0.0\nenvironment:\n  scribe:\n', where),
      throwsToolExit('has no "environment.scribe:"'),
    );
  });

  test('a manifest that is not a mapping is refused', () {
    expect(() => Manifest.parse('- audiences\n', where), throwsToolExit('is not a mapping'));
  });

  test('a key the manifest does not hold is refused by naming the ones it does', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: 1.0.0\n${environment}provides:\n  sql: db\n', where),
      throwsToolExit('which means nothing'),
    );
  });

  test('a version yaml reads as a number is refused by naming why', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: 1.0\n$environment', where),
      throwsToolExit('which YAML reads as a number'),
    );
  });

  test('a version that is not three numbers is refused', () {
    expect(
      () => Manifest.parse('name: audiences\nversion: "1.0"\n$environment', where),
      throwsToolExit('is not a version'),
    );
  });

  test('a name the rule refuses is refused in the manifest too', () {
    expect(
      () => Manifest.parse('name: Audiences\nversion: 1.0.0\n$environment', where),
      throwsToolExit('cannot name a package'),
    );
  });

  test('a dependency named as something other than a package is refused', () {
    expect(
      () =>
          Manifest.parse('name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  Audiences: "^1.0.0"\n', where),
      throwsToolExit('cannot name a package'),
    );
  });

  test('a dependency asked for with a range instead of a constraint is refused', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences: ">=1.0.0 <2.0.0"\n',
        where,
      ),
      throwsToolExit('at "dependencies.audiences:"'),
    );
  });

  test('what a package needs to run its suite is read apart from what it depends on', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences: "^1.0.0"\n'
      'dev_dependencies:\n  sessions: "^2.0.0"\n',
      where,
    );

    expect(manifest.dependencies.keys, <String>['audiences']);
    expect((manifest.devDependencies['sessions'] as SdkSource?)?.constraint, '^2.0.0');
  });

  test('a manifest that names nothing for its suite declares nothing', () {
    expect(Manifest.parse('name: realtime\nversion: 1.0.0\n$environment', where).devDependencies, isEmpty);
  });

  test('a name that reads as a package accepts any as a constraint', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  ioredis: any\n',
      where,
    );

    expect((manifest.dependencies['ioredis'] as SdkSource?)?.constraint, kAny);
  });

  test('a specifier is held to the rules a package name follows, any included', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  "@scribe/contracts/": any\n',
        where,
      ),
      throwsToolExit('cannot name a package'),
    );
  });

  test('a dependency of the suite asked for with a range instead of a constraint is refused', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dev_dependencies:\n  sessions: ">=1.0.0 <2.0.0"\n',
        where,
      ),
      throwsToolExit('at "dev_dependencies.sessions:"'),
    );
  });

  test('a dependency can be given as a local path', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences:\n    path: ../audiences\n',
      where,
    );

    expect((manifest.dependencies['audiences'] as PathSource?)?.path, '../audiences');
  });

  test('a dependency can be given as a git repository', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n'
      '  audiences:\n    git:\n      url: https://example.com/scribe_packages.git\n'
      '      ref: audiences-v1.0.0\n      path: audiences\n',
      where,
    );

    final GitSource? source = manifest.dependencies['audiences'] as GitSource?;
    expect(source?.url, 'https://example.com/scribe_packages.git');
    expect(source?.ref, 'audiences-v1.0.0');
    expect(source?.path, 'audiences');
  });

  test('a git dependency with no ref and no path names both as absent', () {
    final Manifest manifest = Manifest.parse(
      'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n'
      '  audiences:\n    git:\n      url: https://example.com/audiences.git\n',
      where,
    );

    final GitSource? source = manifest.dependencies['audiences'] as GitSource?;
    expect(source?.ref, isNull);
    expect(source?.path, isNull);
  });

  test('a dependency given both a path and a git repository is refused', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n'
        '  audiences:\n    path: ../audiences\n    git:\n      url: https://example.com/audiences.git\n',
        where,
      ),
      throwsToolExit('is given both a path: and a git:'),
    );
  });

  test('a git dependency with no url is refused', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences:\n    git:\n      ref: main\n',
        where,
      ),
      throwsToolExit('has no "url:"'),
    );
  });

  test('a dependency given a key this does not read is refused', () {
    expect(
      () => Manifest.parse(
        'name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences:\n    sdk: scribe\n',
        where,
      ),
      throwsToolExit('carries sdk, which is not read'),
    );
  });

  test('a dependency given an empty block is refused', () {
    expect(
      () => Manifest.parse('name: realtime\nversion: 1.0.0\n${environment}dependencies:\n  audiences: {}\n', where),
      throwsToolExit('names neither a version, a path:, nor a git:'),
    );
  });
}
