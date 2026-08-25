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
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:test/test.dart';

Matcher throwsToolExit(String saying) =>
    throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

void main() {
  const String where = 'foundation/package.yaml';
  const String head = 'name: foundation\nversion: 1.0.0\nenvironment:\n  scribe: "^3.0.0"\n';

  Manifest parse(String block) => Manifest.parse('$head$block', where);

  test('a manifest with no scribe block hands the stack nothing', () {
    expect(parse('').artefacts.isEmpty, isTrue);
  });

  test('a scribe block reads the three moments sql is played at', () {
    final Manifest manifest = parse(
      'scribe:\n'
      '  db:\n'
      '    init: ./db/init/\n'
      '    migrations: ./db/migrations/\n'
      '    provisioning: ./db/provisioning/\n',
    );

    expect(manifest.artefacts.db!.init, 'db/init');
    expect(manifest.artefacts.db!.migrations, 'db/migrations');
    expect(manifest.artefacts.db!.provisioning, 'db/provisioning');
  });

  test('a db block may name one moment and leave the others out', () {
    final Manifest manifest = parse('scribe:\n  db:\n    init: ./db/init/\n');

    expect(manifest.artefacts.db!.init, 'db/init');
    expect(manifest.artefacts.db!.migrations, isNull);
  });

  test('ops reads one entry per service, in the order written', () {
    final Manifest manifest = parse('scribe:\n  ops:\n    - ./ops/database/\n    - ./ops/queue/\n');

    expect(manifest.artefacts.ops, <String>['ops/database', 'ops/queue']);
  });

  test('an ops entry may be a single fragment rather than a directory', () {
    final Manifest manifest = parse('scribe:\n  ops:\n    - ./ops/docker-compose.yaml\n');

    expect(manifest.artefacts.ops, <String>['ops/docker-compose.yaml']);
  });

  test('protocol reads the directory the proto files sit in', () {
    expect(parse('scribe:\n  protocol: ./protocol/\n').artefacts.protocol, 'protocol');
  });

  test('every declared path is named with the key that named it', () {
    final Manifest manifest = parse('scribe:\n  db:\n    init: ./db/init/\n  ops:\n    - ./ops/queue/\n');

    expect(manifest.artefacts.declared, <String, String>{'scribe.db.init': 'db/init', 'scribe.ops[0]': 'ops/queue'});
  });

  test('declarations read one bucket per kind, the value marking a file', () {
    final Manifest manifest = parse('scribe:\n  declarations:\n    queues: Queue\n    crons: Cron\n');

    expect(manifest.artefacts.declarations, <String, String>{'queues': 'Queue', 'crons': 'Cron'});
  });

  test('a package that opens no bucket declares none, and the block is still empty', () {
    expect(parse('scribe:\n  declarations:\n').artefacts.declarations, isEmpty);
    expect(parse('scribe:\n  declarations:\n').artefacts.isEmpty, isTrue);
  });

  test('a package that opens a bucket hands the stack something', () {
    expect(parse('scribe:\n  declarations:\n    queues: Queue\n').artefacts.isEmpty, isFalse);
  });

  test('declarations written as anything but a block is refused', () {
    expect(() => parse('scribe:\n  declarations: Queue\n'), throwsToolExit('something other than a block'));
  });

  test('a bucket a source file could not spell is refused, since it is written out as a function', () {
    expect(
      () => parse('scribe:\n  declarations:\n    my queues: Queue\n'),
      throwsToolExit('not a name a source file could spell'),
    );
  });

  test('a marker a source file could not spell is refused, since it is compared to an import', () {
    expect(
      () => parse('scribe:\n  declarations:\n    queues: 3\n'),
      throwsToolExit('not a name a source file could spell'),
    );
  });

  test('a key beside the four in the scribe block is refused', () {
    expect(() => parse('scribe:\n  seeds: ./db/seeds/\n'), throwsToolExit('"scribe.seeds:", which means nothing'));
  });

  test('a key the db block does not hold is refused by naming the three moments', () {
    expect(
      () => parse('scribe:\n  db:\n    seed: ./db/seed/\n'),
      throwsToolExit('"scribe.db.seed:", which means nothing'),
    );
  });

  test('a block with nothing under it hands over nothing, the way an empty dependencies does', () {
    final Manifest manifest = parse('scribe:\n  db:\n  ops: []\n  protocol: ./protocol/\n');

    expect(manifest.artefacts.db, isNull);
    expect(manifest.artefacts.ops, isEmpty);
    expect(manifest.artefacts.protocol, 'protocol');
  });

  test('ops written as a single path instead of a list is refused', () {
    expect(() => parse('scribe:\n  ops: ./ops/\n'), throwsToolExit('something other than a list'));
  });

  test('a scribe block that is not a mapping is refused', () {
    expect(() => parse('scribe: ./ops/\n'), throwsToolExit('something other than a block of paths'));
  });

  test('an absolute path is refused', () {
    expect(() => parse('scribe:\n  protocol: /srv/protocol/\n'), throwsToolExit('which is an absolute path'));
  });

  test('a path that climbs out of the package is refused', () {
    expect(() => parse('scribe:\n  protocol: ../auth/protocol/\n'), throwsToolExit('which climbs out of the package'));
  });

  test('the same ops entry named twice is refused', () {
    expect(
      () => parse('scribe:\n  ops:\n    - ./ops/queue/\n    - ./ops/queue\n'),
      throwsToolExit('names "ops/queue" twice'),
    );
  });
}
