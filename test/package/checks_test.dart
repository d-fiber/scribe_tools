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
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  const Sdk sdk = Sdk(root: '/checkout', version: '3.0.1');
  const String environment = 'environment:\n  scribe: "^3.0.0"\n';

  setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
  tearDown(() => root.deleteSync(recursive: true));

  String written(String name, {String? manifest}) {
    final CreatedPackage created = createPackage(root.path, name, sdk);
    if (manifest != null) {
      File(p.join(created.directory, 'package.yaml')).writeAsStringSync(manifest);
    }
    return created.directory;
  }

  List<String> problemsUnder() =>
      check(discover(<String>[root.path])).map((Problem problem) => problem.toString()).toList();

  test('a package with no ignore file is reported', () {
    final String audiences = written('audiences');
    File(p.join(audiences, '.gitignore')).deleteSync();

    expect(problemsUnder().single, contains('would be committed with the source'));
  });

  test('a package with no entry is reported', () {
    final String audiences = written('audiences');
    File(p.join(audiences, 'lib', 'audiences.ts')).deleteSync();

    expect(problemsUnder().single, contains('the one file everything else reaches it through'));
  });

  test('a package with no source directory is reported', () {
    final String audiences = written('audiences');
    Directory(p.join(audiences, 'lib', 'src')).deleteSync(recursive: true);

    expect(problemsUnder().single, contains('where the code goes'));
  });

  test('a package with no tests is reported', () {
    final String audiences = written('audiences');
    Directory(p.join(audiences, 'tests')).deleteSync(recursive: true);

    expect(problemsUnder().single, contains('a package nobody tested is not one'));
  });

  test('a package whose tests hold no test is reported', () {
    final String audiences = written('audiences');
    File(p.join(audiences, 'tests', 'audiences.test.ts')).deleteSync();

    expect(problemsUnder().single, contains('says it was tested and nothing did'));
  });

  test('a package with no end to end directory is reported', () {
    final String audiences = written('audiences');
    Directory(p.join(audiences, 'tests', 'e2e')).deleteSync(recursive: true);

    expect(problemsUnder().single, contains('need the stack up'));
  });

  test('a package living under another name is reported', () {
    final String audiences = written('audiences');
    Directory(audiences).renameSync(p.join(root.path, 'listeners'));

    expect(problemsUnder().single, contains('have to match'));
  });

  test('a scribe block in the manifest is refused, since what a package hands over is read from its tree', () {
    written('audiences', manifest: 'name: audiences\nversion: 1.0.0\n${environment}scribe:\n  protocol: ./protocol/\n');

    expect(
      problemsUnder,
      throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains('"scribe"'))),
    );
  });

  test('a missing deploy tree directory is reported through the ordinary layout check', () {
    final String audiences = written('audiences');
    Directory(p.join(audiences, 'deploy', 'db', 'init')).deleteSync(recursive: true);

    expect(problemsUnder().single, contains('it has no deploy/db/init/'));
  });

  test('a service directory carrying a fragment is not reported', () {
    final String audiences = written('audiences');
    _fragment(p.join(audiences, 'deploy', 'services', 'db', 'docker-compose.yaml'));

    expect(problemsUnder(), isEmpty);
  });

  test('two packages opening the same bucket through their entry are both named', () {
    final String audiences = written('audiences');
    final String realtime = written('realtime');
    File(p.join(audiences, 'lib', 'audiences.ts')).writeAsStringSync('export const declares = { accounts: Role };\n');
    File(p.join(realtime, 'lib', 'realtime.ts')).writeAsStringSync('export const declares = { accounts: Grant };\n');

    expect(problemsUnder().single, contains('it opens "accounts", and so does'));
  });

  test('a dependency on a package nobody wrote is reported', () {
    written(
      'realtime',
      manifest: 'name: realtime\nversion: 1.0.0\n\n${environment}dependencies:\n  audiences: "^1.0.0"\n',
    );

    expect(problemsUnder().single, contains('no package of that name exists'));
  });

  test('a constraint the copy on hand fails is reported', () {
    written('audiences', manifest: 'name: audiences\nversion: 2.0.0\n$environment');
    written(
      'realtime',
      manifest: 'name: realtime\nversion: 1.0.0\n\n${environment}dependencies:\n  audiences: "^1.0.0"\n',
    );

    expect(problemsUnder().single, contains('the copy on hand is 2.0.0'));
  });

  test('a caret constraint the copy on hand answers is not reported', () {
    written('audiences', manifest: 'name: audiences\nversion: 1.4.0\n$environment');
    written(
      'realtime',
      manifest: 'name: realtime\nversion: 1.0.0\n\n${environment}dependencies:\n  audiences: "^1.0.0"\n',
    );

    expect(problemsUnder(), isEmpty);
  });

  test('a caret constraint below one stops at the next minor', () {
    written('audiences', manifest: 'name: audiences\nversion: 0.2.0\n$environment');
    written(
      'realtime',
      manifest: 'name: realtime\nversion: 1.0.0\n\n${environment}dependencies:\n  audiences: "^0.1.0"\n',
    );

    expect(problemsUnder().single, contains('the copy on hand is 0.2.0'));
  });

  test('a specifier the checkout pins is not looked for among the packages', () {
    written(
      'realtime',
      manifest:
          'name: realtime\nversion: 1.0.0\n\n${environment}dependencies:\n'
          '  ioredis: any\n  "@scribe/core/": any\n',
    );

    expect(problemsUnder(), isEmpty, reason: 'what the checkout answers for was held against the package');
  });

  test('a dependency of the suite on a package nobody wrote is reported', () {
    written(
      'realtime',
      manifest: 'name: realtime\nversion: 1.0.0\n\n${environment}dev_dependencies:\n  audiences: "^1.0.0"\n',
    );

    expect(problemsUnder().single, contains('no package of that name exists'));
  });
}

void _fragment(String path) => File(path)
  ..parent.createSync(recursive: true)
  ..writeAsStringSync('services: {}\n');
