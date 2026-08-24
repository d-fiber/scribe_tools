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
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:test/test.dart';

import 'sdk_source.dart';

const String _sound = '''
name: audiences
description: Says who belongs to what.
version: 1.0.0

environment:
  scribe: "^3.0.0"

dependencies:

scribe:
  db:
    init: ./db/init/
    migrations: ./db/migrations/
    provisioning: ./db/provisioning/
  protocol: ./protocol/
  ops:
    - ./ops/listener/
    - ./ops/reader/
''';

void main() {
  late Directory root;
  late Directory checkout;
  late Directory home;
  late Sdk sdk;

  setUp(() {
    checkout = Directory.systemTemp.createTempSync('scribe_sdk_');
    home = Directory.systemTemp.createTempSync('scribe_home_');
    sdk = Sdk(root: checkout.path, version: '3.0.1');
    root = Directory(p.join(checkout.path, 'work'))..createSync(recursive: true);
    writeCheckout(checkout);
  });

  tearDown(() {
    checkout.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  });

  void holding(String name, void Function() body) => test(name, () => withHome(home, body));

  String write(String path, String text) {
    final File file = File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    return file.path;
  }

  String sound({String manifest = _sound}) {
    createPackage(root.path, 'audiences', sdk);
    final String at = p.join(root.path, 'audiences');

    write(p.join(at, 'package.yaml'), manifest);
    write(p.join(at, 'db', 'init', '00_tables.sql'), 'create table audiences ();\n');
    write(p.join(at, 'db', 'migrations', '20260101_open.sql'), 'select 1;\n');
    write(p.join(at, 'db', 'provisioning', 'roles.sql'), 'select 1;\n');
    write(p.join(at, 'protocol', 'audiences.proto'), 'syntax = "proto3";\n');
    write(p.join(at, 'ops', 'listener', 'docker-compose.yaml'), 'services: {}\n');
    write(p.join(at, 'ops', 'listener', 'capacity.yaml'), 'weight: 1\n');
    write(p.join(at, 'ops', 'listener', 'Dockerfile'), 'FROM scratch\n');
    write(p.join(at, 'ops', 'listener', 'run-migrations.sh'), 'exit 0\n');
    write(p.join(at, 'ops', 'reader', 'docker-compose.yaml'), 'services: {}\n');

    return at;
  }

  List<String> reported(String at) => problemsWithin(
    DiscoveredPackage(manifest: loadManifest(at), directory: at),
  ).map((Problem problem) => problem.message).toList();

  Matcher refuses(String saying) =>
      throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

  String broken(String manifest) {
    final String at = sound();
    write(p.join(at, 'package.yaml'), manifest);
    return at;
  }

  String withoutLine(String line) => _sound.split('\n').where((String each) => each.trim() != line).join('\n');

  String replacing(String line, String by) =>
      _sound.split('\n').map((String each) => each.trim() == line ? by : each).join('\n');

  group('a package that holds together', () {
    holding('is reported clean, and resolves', () {
      final String at = sound();

      expect(reported(at), isEmpty);
      expect(resolve(at, sdk).imports['@scribe/audiences'], isNotNull);
    });

    holding('keeps the files a fragment reaches by path, which nothing declares', () {
      final String at = sound();

      expect(File(p.join(at, 'ops', 'listener', 'Dockerfile')).existsSync(), isTrue);
      expect(File(p.join(at, 'ops', 'listener', 'run-migrations.sh')).existsSync(), isTrue);
      expect(reported(at), isEmpty, reason: 'a file nothing looks up by name was held against the package');
    });
  });

  group('a manifest whose text is wrong is refused as it is read', () {
    holding('no name at all', () {
      expect(() => loadManifest(broken(withoutLine('name: audiences'))), refuses('has no "name:"'));
    });

    holding('a name written empty', () {
      expect(
        () => loadManifest(broken(replacing('name: audiences', 'name: ""'))),
        refuses('nothing after it but space'),
      );
    });

    holding('a name that is only space', () {
      expect(
        () => loadManifest(broken(replacing('name: audiences', 'name: "   "'))),
        refuses('nothing after it but space'),
      );
    });

    holding('a name with a capital in it', () {
      expect(
        () => loadManifest(broken(replacing('name: audiences', 'name: Audiences'))),
        refuses('cannot name a package'),
      );
    });

    holding('a name with a dash in it', () {
      expect(
        () => loadManifest(broken(replacing('name: audiences', 'name: dynamic-links'))),
        refuses('cannot name a package'),
      );
    });

    holding('a name with a digit in it', () {
      expect(() => loadManifest(broken(replacing('name: audiences', 'name: s3'))), refuses('cannot name a package'));
    });

    holding('a name the framework keeps for itself', () {
      expect(() => loadManifest(broken(replacing('name: audiences', 'name: core'))), refuses('keeps for itself'));
    });

    holding('no version', () {
      expect(() => loadManifest(broken(withoutLine('version: 1.0.0'))), refuses('has no "version:"'));
    });

    holding('a version yaml reads as a number', () {
      expect(
        () => loadManifest(broken(replacing('version: 1.0.0', 'version: 1.0'))),
        refuses('YAML reads as a number'),
      );
    });

    holding('a version that is not three numbers', () {
      expect(() => loadManifest(broken(replacing('version: 1.0.0', 'version: "1.0"'))), refuses('is not a version'));
    });

    holding('a version with a suffix on it', () {
      expect(
        () => loadManifest(broken(replacing('version: 1.0.0', 'version: "1.0.0-beta"'))),
        refuses('is not a version'),
      );
    });

    holding('an environment block whose framework is written empty', () {
      expect(
        () => loadManifest(broken(replacing('scribe: "^3.0.0"', '  scribe:'))),
        refuses('has no "environment.scribe:"'),
      );
    });

    holding('an environment block with a key beside the framework', () {
      expect(
        () => loadManifest(broken(replacing('scribe: "^3.0.0"', '  deno: "^2.0.0"'))),
        refuses('"environment.deno:", which means nothing'),
      );
    });

    holding('no environment block at all', () {
      expect(
        () => loadManifest(broken(_sound.replaceFirst('environment:\n  scribe: "^3.0.0"\n', ''))),
        refuses('has no "environment:"'),
      );
    });

    holding('a framework constraint written as a range', () {
      expect(
        () => loadManifest(broken(replacing('scribe: "^3.0.0"', '  scribe: ">=3.0.0 <4.0.0"'))),
        refuses('is not a constraint'),
      );
    });

    holding('a key the manifest does not hold', () {
      expect(() => loadManifest(broken('$_sound\nprovides:\n  sql: db\n')), refuses('which means nothing'));
    });

    holding('a key the scribe block does not hold', () {
      expect(
        () => loadManifest(broken('$_sound  seeds: ./db/seeds/\n')),
        refuses('"scribe.seeds:", which means nothing'),
      );
    });

    holding('an absolute path', () {
      expect(
        () => loadManifest(broken(replacing('protocol: ./protocol/', '  protocol: /srv/protocol/'))),
        refuses('is an absolute path'),
      );
    });

    holding('a path that reaches into a neighbour', () {
      expect(
        () => loadManifest(broken(replacing('protocol: ./protocol/', '  protocol: ../auth/protocol/'))),
        refuses('climbs out of the package'),
      );
    });

    holding('ops written as one path instead of a list', () {
      expect(
        () => loadManifest(
          broken(_sound.replaceFirst('  ops:\n    - ./ops/listener/\n    - ./ops/reader/\n', '  ops: ./ops/\n')),
        ),
        refuses('something other than a list'),
      );
    });

    holding('the same service named twice', () {
      expect(
        () => loadManifest(broken(replacing('- ./ops/reader/', '    - ./ops/listener'))),
        refuses('names "ops/listener" twice'),
      );
    });
  });

  group('a manifest the tree contradicts is reported by the checks', () {
    holding('a declared directory that is not there', () {
      final String at = sound();
      Directory(p.join(at, 'protocol')).deleteSync(recursive: true);

      expect(reported(at).single, contains('names "protocol", and nothing is there'));
    });

    holding('a declared directory that is there and empty', () {
      final String at = sound();
      File(p.join(at, 'protocol', 'audiences.proto')).deleteSync();

      expect(reported(at).single, contains('carries no .proto file'));
    });

    holding('a declared sql directory holding files of another kind', () {
      final String at = sound();
      File(p.join(at, 'db', 'init', '00_tables.sql')).renameSync(p.join(at, 'db', 'init', 'notes.md'));

      expect(reported(at).single, contains('carries no .sql file'));
    });

    holding('a declared directory that turned out to be a file', () {
      final String at = sound();
      Directory(p.join(at, 'protocol')).deleteSync(recursive: true);
      write(p.join(at, 'protocol'), 'syntax = "proto3";\n');

      expect(reported(at).single, contains('which is a file'));
    });

    holding('a service directory holding no fragment', () {
      final String at = sound();
      File(p.join(at, 'ops', 'reader', 'docker-compose.yaml')).deleteSync();
      write(p.join(at, 'ops', 'reader', 'Dockerfile'), 'FROM scratch\n');

      expect(reported(at).single, contains('holds no fragment'));
    });

    holding('an ops entry naming a file no template pairs with', () {
      final String at = sound();
      write(p.join(at, 'ops', 'reader', 'settings.yaml'), 'a: 1\n');
      write(p.join(at, 'package.yaml'), replacing('- ./ops/reader/', '    - ./ops/reader/settings.yaml'));

      expect(reported(at).single, contains('is not a fragment'));
    });

    holding('an ops entry naming a fragment by its own name is taken', () {
      final String at = sound();
      write(p.join(at, 'package.yaml'), replacing('- ./ops/reader/', '    - ./ops/reader/docker-compose.yaml'));

      expect(reported(at), isEmpty);
    });

    holding('a package whose entry file went', () {
      final String at = sound();
      File(p.join(at, 'lib', 'audiences.ts')).deleteSync();

      expect(reported(at).single, contains('the one file everything else reaches it through'));
    });

    holding('a package living under a name other than the one it declares', () {
      final String at = sound();
      Directory(at).renameSync(p.join(root.path, 'listeners'));

      expect(
        problemsWithin(
          DiscoveredPackage(
            manifest: loadManifest(p.join(root.path, 'listeners')),
            directory: p.join(root.path, 'listeners'),
          ),
        ).single.message,
        contains('have to match'),
      );
    });

    holding('every fault is reported at once, not one run per fault', () {
      final String at = sound();
      Directory(p.join(at, 'protocol')).deleteSync(recursive: true);
      Directory(p.join(at, 'ops', 'reader')).deleteSync(recursive: true);
      File(p.join(at, 'lib', 'audiences.ts')).deleteSync();

      expect(reported(at).length, 3);
    });
  });

  group('a package that does not hold together reaches nothing', () {
    holding('a declared directory that is not there stops the resolution', () {
      final String at = sound();
      Directory(p.join(at, 'ops', 'reader')).deleteSync(recursive: true);

      expect(() => resolve(at, sdk), refuses('does not hold together'));
    });

    holding('nothing is written when the resolution is refused', () {
      final String at = sound();
      Directory(p.join(at, 'ops', 'reader')).deleteSync(recursive: true);

      expect(() => resolve(at, sdk), throwsA(isA<ToolExit>()));
      expect(
        Directory(p.join(at, kResolutionDirectory)).existsSync(),
        isFalse,
        reason: 'a refused package left a resolution behind for the next command to trust',
      );
    });

    holding('the refusal names every fault, so one run says all of it', () {
      final String at = sound();
      Directory(p.join(at, 'protocol')).deleteSync(recursive: true);
      File(p.join(at, 'lib', 'audiences.ts')).deleteSync();

      expect(() => resolve(at, sdk), refuses('names "protocol", and nothing is there'));
      expect(() => resolve(at, sdk), refuses('the one file everything else reaches it through'));
    });

    holding('a checkout the package refuses stops the resolution too', () {
      final String at = sound(manifest: _sound.replaceFirst('^3.0.0', '^9.0.0'));

      expect(() => resolve(at, sdk), refuses('accepts scribe ^9.0.0'));
    });

    holding('a package that holds together resolves against the checkout it accepts', () {
      final String at = sound();

      expect(File(resolve(at, sdk).file).existsSync(), isTrue);
    });
  });
}
