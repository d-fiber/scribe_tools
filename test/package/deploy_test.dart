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
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('scribe_'));
  tearDown(() => root.deleteSync(recursive: true));

  void keep(String relative) => File(p.join(root.path, relative, '.gitkeep'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('');

  void scaffoldDeploy() {
    keep('deploy/db/init');
    keep('deploy/db/migrations');
  }

  test('a package carrying the mandatory deploy tree and nothing else passes', () {
    scaffoldDeploy();

    expect(deployProblems(root.path), isEmpty);
  });

  test('a package with no deploy directory at all is reported', () {
    expect(deployProblems(root.path).single, contains('it has no deploy/'));
  });

  test('a deploy directory with no db is reported', () {
    Directory(p.join(root.path, 'deploy')).createSync(recursive: true);

    expect(deployProblems(root.path).single, contains('it has no deploy/db/'));
  });

  test('a db directory missing init is reported', () {
    keep('deploy/db/migrations');

    expect(deployProblems(root.path).single, contains('it has no deploy/db/init/'));
  });

  test('a db directory missing migrations is reported', () {
    keep('deploy/db/init');

    expect(deployProblems(root.path).single, contains('it has no deploy/db/migrations/'));
  });

  test('provisioning is optional, and its absence is not reported', () {
    scaffoldDeploy();

    expect(deployProblems(root.path), isEmpty);
  });

  test('deploy/db/provisioning present and empty is reported', () {
    scaffoldDeploy();
    Directory(p.join(root.path, 'deploy', 'db', 'provisioning')).createSync(recursive: true);

    expect(deployProblems(root.path).single, contains('deploy/db/provisioning/ is there and empty'));
  });

  test('deploy/services present and empty is reported', () {
    scaffoldDeploy();
    Directory(p.join(root.path, 'deploy', 'services')).createSync(recursive: true);

    expect(deployProblems(root.path).single, contains('deploy/services/ is there and empty'));
  });

  test('deploy/recipes present and empty is reported', () {
    scaffoldDeploy();
    Directory(p.join(root.path, 'deploy', 'recipes')).createSync(recursive: true);

    expect(deployProblems(root.path).single, contains('deploy/recipes/ is there and empty'));
  });

  test('a stray file directly under deploy is reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'packages.yaml')).writeAsStringSync('');

    expect(deployProblems(root.path).single, contains('carries "packages.yaml", which means nothing there'));
  });

  test('a stray entry directly under deploy/db is reported', () {
    scaffoldDeploy();
    keep('deploy/db/seed');

    expect(deployProblems(root.path).single, contains('carries "seed", which means nothing there'));
  });

  test('the three files deploy reads where they sit are not stray', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'overlay.yaml')).writeAsStringSync('');
    File(p.join(root.path, 'deploy', 'configuration.yaml')).writeAsStringSync('');
    File(p.join(root.path, 'deploy', 'packages.env')).writeAsStringSync('');

    expect(deployProblems(root.path), isEmpty);
  });

  test('a service directory with neither mandatory fragment is reported', () {
    scaffoldDeploy();
    keep('deploy/services/queue');

    final List<String> problems = deployProblems(root.path)..sort();
    expect(problems, hasLength(2));
    expect(problems[0], contains('deploy/services/queue/ has no capacity.yaml'));
    expect(problems[1], contains('deploy/services/queue/ has no docker-compose.yaml'));
  });

  test('a service directory carrying only one mandatory fragment is reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'services', 'queue', 'docker-compose.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('services: {}\n');

    expect(deployProblems(root.path).single, contains('deploy/services/queue/ has no capacity.yaml'));
  });

  test('a service directory carrying both mandatory fragments is not reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'services', 'queue', 'docker-compose.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('services: {}\n');
    File(p.join(root.path, 'deploy', 'services', 'queue', 'capacity.yaml')).writeAsStringSync('services: []\n');

    expect(deployProblems(root.path), isEmpty);
  });

  test('a recipe directory with no contract is reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'recipes', 'bucket', 'container.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('outputs: {}\n');

    expect(deployProblems(root.path).single, contains('deploy/recipes/bucket/ has no contract.yaml'));
  });

  test('a recipe directory carrying a contract is not reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'deploy', 'recipes', 'bucket', 'contract.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('outputs: {}\n');

    expect(deployProblems(root.path), isEmpty);
  });

  test('a protocol directory with no proto file is reported', () {
    scaffoldDeploy();
    Directory(p.join(root.path, 'protocol')).createSync(recursive: true);

    expect(deployProblems(root.path).single, contains('its protocol/ holds no .proto file'));
  });

  test('a protocol directory carrying a proto file is not reported', () {
    scaffoldDeploy();
    File(p.join(root.path, 'protocol', 'queue.proto'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('syntax = "proto3";\n');

    expect(deployProblems(root.path), isEmpty);
  });

  test('no protocol directory at all is not reported, since it is optional', () {
    scaffoldDeploy();

    expect(deployProblems(root.path), isEmpty);
  });
}
