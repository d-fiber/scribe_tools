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
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/packages.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

/// Creates a package called [name] under [root], with the contract every package has.
Directory _package(Directory root, String name) {
  final Directory directory = root.childDirectory(name)..createSync(recursive: true);
  directory.childDirectory('protocol').createSync(recursive: true);
  return directory;
}

/// Gives [package] a compose fragment holding [services].
void _compose(Directory package, String services) {
  final Directory ops = package.childDirectory('ops')..createSync(recursive: true);
  ops.childFile('docker-compose.yaml').writeAsStringSync('services:\n$services');
}

Directory _root() => fs.directory(p.join('/tree', 'packages'))..createSync(recursive: true);

List<String> _namesOf(Iterable<Package> found) => found.map((Package package) => package.name).toList();

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  group('the packages root', () {
    test('a package is named after its directory, and by one segment', () {
      final Directory root = _root();
      _package(root, 'auth');

      expect(_namesOf(Packages.load(root: root).all), <String>['auth']);
    });

    test('what is found comes back sorted by name', () {
      final Directory root = _root();
      _package(root, 'storage');
      _package(root, 'auth');
      _package(root, 'realtime');

      expect(_namesOf(Packages.load(root: root).all), <String>['auth', 'realtime', 'storage']);
    });

    test('a root that is not there yields nothing rather than failing', () {
      expect(_namesOf(Packages.load(root: fs.directory('/tree/packages')).all), isEmpty);
    });

    test('byName finds a package the root carries', () {
      final Directory root = _root();
      _package(root, 'auth');
      _package(root, 'storage');

      final Packages found = Packages.load(root: root);

      expect(found.byName('auth')?.name, 'auth');
      expect(found.byName('storage')?.name, 'storage');
      expect(found.byName('nowhere'), isNull);
    });

    test('a directory carrying none of the artefacts is not a package', () {
      final Directory root = _root();
      root.childDirectory('tool').createSync(recursive: true);
      _package(root, 'search');

      expect(_namesOf(Packages.load(root: root).all), <String>['search']);
    });

    test('the subjects inside a package are not packages of their own', () {
      final Directory root = _root();
      final Directory package = _package(root, 'foundation');
      package.childDirectory('ops').childDirectory('database').createSync(recursive: true);
      package.childDirectory('lib').childDirectory('queue').childDirectory('protocol').createSync(recursive: true);

      expect(_namesOf(Packages.load(root: root).all), <String>['foundation']);
    });

    test('a package nested one level down is not found, since a name is one segment', () {
      final Directory root = _root();
      _package(root.childDirectory('security')..createSync(recursive: true), 'auth');

      expect(_namesOf(Packages.load(root: root).all), isEmpty);
    });

    test('any one of the artefacts is enough, whether it is a file or a directory', () {
      for (final String artefact in packageArtefacts) {
        fs = MemoryFileSystem.test();
        final Directory root = _root();
        final Directory package = root.childDirectory('one')..createSync(recursive: true);
        if (artefact.contains('.')) {
          package.childFile(artefact).createSync();
        } else {
          package.childDirectory(artefact).createSync();
        }

        expect(_namesOf(Packages.load(root: root).all), <String>['one'], reason: artefact);
      }
    });
  });

  group('what a project mounts', () {
    late Packages found;

    setUp(() {
      final Directory root = _root();
      _package(root, 'foundation');
      _package(root, 'realtime');
      _package(root, 'auth');
      _package(root, 'audience');

      found = Packages.load(root: root);
    });

    test('a project that names nothing gets foundation and nothing else', () {
      expect(_namesOf(found.selected(const <String>[])), <String>['foundation']);
    });

    test('a project gets foundation on top of what it named', () {
      expect(_namesOf(found.selected(const <String>['auth'])), <String>['auth', 'foundation']);
    });

    test('naming a package never drags a neighbour in with it', () {
      expect(
        _namesOf(found.selected(const <String>['audience'])),
        <String>['audience', 'foundation'],
        reason: 'audience is written against auth, and says so at the endpoint rather than here',
      );
    });

    test('naming a package that does not exist fails and lists the ones that do', () {
      expect(
        () => found.selected(const <String>['nope']),
        throwsA(
          isA<Exception>().having(
            (Exception error) => error.toString(),
            'message',
            allOf(contains('unknown package "nope"'), contains('auth')),
          ),
        ),
      );
    });

    test('a two segment address is refused, because it names nothing any more', () {
      expect(
        () => found.selected(const <String>['security/auth']),
        throwsA(
          isA<Exception>().having(
            (Exception error) => error.toString(),
            'message',
            contains('unknown package "security/auth"'),
          ),
        ),
      );
    });
  });

  group('what a package ships', () {
    test('the sql it adds is the db/init it carries', () {
      final Directory root = _root();
      final Directory package = _package(root, 'auth');
      package.childDirectory('db').childDirectory('init').createSync(recursive: true);
      package.childDirectory('db').childDirectory('migrations').createSync(recursive: true);

      expect(Packages.load(root: root).all.single.sql?.path, package.childDirectory('db').childDirectory('init').path);
    });

    test('a package without a db directory adds no sql', () {
      final Directory root = _root();
      _package(root, 'audience');

      expect(Packages.load(root: root).all.single.sql, isNull);
    });

    test('its profiles are the ones its compose fragment names', () {
      final Directory root = _root();
      _compose(_package(root, 'search'), '  opensearch:\n    profiles: ["search"]\n');

      expect(Packages.load(root: root).all.single.profiles, <String>{'search'});
    });

    test('a profile written as a block list is read too', () {
      final Directory root = _root();
      _compose(_package(root, 'search'), '  opensearch:\n    profiles:\n      - search\n');

      expect(Packages.load(root: root).all.single.profiles, <String>{'search'});
    });

    test('a package whose services name no profile always starts them', () {
      final Directory root = _root();
      _compose(_package(root, 'storage'), '  storage:\n    image: "storage-api"\n');

      expect(Packages.load(root: root).all.single.profiles, isEmpty);
    });

    test('a profile is named once however many services sit behind it', () {
      final Directory root = _root();
      _compose(
        _package(root, 'realtime'),
        '  realtime:\n    profiles: ["realtime"]\n  realtime-init:\n    profiles: ["realtime"]\n',
      );
      _compose(_package(root, 'search'), '  opensearch:\n    profiles: ["search"]\n');

      expect(Packages.profilesOf(Packages.load(root: root).all), <String>['realtime', 'search']);
    });

    test('a fragment in a subject directory is labelled with the subject', () {
      final Directory root = _root();
      final Directory package = _package(root, 'foundation');
      final Directory subject = package.childDirectory('ops').childDirectory('valkery')..createSync(recursive: true);
      subject.childFile('docker-compose.yaml').writeAsStringSync('services:\n  redis:\n');

      expect(
        Packages.load(root: root).all.single.fragmentsFor('docker-compose.yaml').single.label,
        'foundation/valkery',
      );
    });
  });
}
