// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/dependencies.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

/// Creates a module at [path] under [root], with the contract every module has.
Directory _module(Directory root, String path) {
  final Directory directory = root.childDirectory(path)..createSync(recursive: true);
  directory.childDirectory('protocol').createSync(recursive: true);
  return directory;
}

/// Gives [module] a compose fragment holding [services].
void _compose(Directory module, String services) {
  final Directory ops = module.childDirectory('ops')..createSync(recursive: true);
  ops.childFile('docker-compose.yaml').writeAsStringSync('services:\n$services');
}

Directory _root(String name) => fs.directory(p.join('/tree', name))..createSync(recursive: true);

List<String> _pathsOf(Iterable<Dependency> found) =>
    found.map((Dependency dependency) => dependency.path).toList();

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  group('the two dependency roots', () {
    test('a module is addressed relative to the root that carries it', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest');
      _module(packages, 'security/auth');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, packages]).all),
        <String>['database/rest', 'security/auth'],
      );
    });

    test('a module keeps its address when it moves from one root to the other', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'security/auth');

      final String before = Dependencies.load(roots: <Directory>[owned, packages]).all.single.path;

      owned.childDirectory('security').deleteSync(recursive: true);
      _module(packages, 'security/auth');

      final String after = Dependencies.load(roots: <Directory>[owned, packages]).all.single.path;

      expect(after, before);
      expect(after, 'security/auth');
    });

    test('the modules of both roots are merged into one sorted list', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest');
      _module(packages, 'features/searcher');
      _module(packages, 'database/storage');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, packages]).all),
        <String>['database/rest', 'database/storage', 'features/searcher'],
      );
    });

    test('a root that does not exist yields nothing rather than failing', () {
      final Directory owned = _root('dependencies');
      _module(owned, 'database/rest');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, fs.directory('/tree/packages')]).all),
        <String>['database/rest'],
      );
    });

    test('byPath finds a module whichever root carries it', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest');
      _module(packages, 'security/auth');

      final Dependencies found = Dependencies.load(roots: <Directory>[owned, packages]);

      expect(found.byPath('security/auth')?.path, 'security/auth');
      expect(found.byPath('database/rest')?.path, 'database/rest');
    });

    test('a directory carrying none of the artefacts is not a module', () {
      final Directory owned = _root('dependencies');
      owned.childDirectory('features/notes').createSync(recursive: true);
      _module(owned, 'features/searcher');

      expect(_pathsOf(Dependencies.load(roots: <Directory>[owned]).all), <String>['features/searcher']);
    });

    test('the subjects inside a module are not modules of their own', () {
      final Directory packages = _root('packages');
      final Directory module = _module(packages, 'foundation');
      module.childDirectory('ops').childDirectory('database').createSync(recursive: true);
      module.childDirectory('src').childDirectory('queue').childDirectory('protocol').createSync(recursive: true);

      expect(_pathsOf(Dependencies.load(roots: <Directory>[packages]).all), <String>['foundation']);
    });

    test('any one of the artefacts is enough, whether it is a file or a directory', () {
      for (final String artefact in moduleArtefacts) {
        final Directory root = _root('root-$artefact');
        final Directory module = root.childDirectory('security/one')..createSync(recursive: true);
        if (artefact.contains('.')) {
          module.childFile(artefact).createSync();
        } else {
          module.childDirectory(artefact).createSync();
        }

        expect(
          _pathsOf(Dependencies.load(roots: <Directory>[root]).all),
          <String>['security/one'],
          reason: artefact,
        );
      }
    });
  });

  group('what a project mounts', () {
    late Dependencies found;

    setUp(() {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(packages, 'foundation');
      _module(packages, 'realtime');
      _module(owned, 'security/auth');
      _module(owned, 'security/rbac');

      found = Dependencies.load(roots: <Directory>[owned, packages]);
    });

    test('a project that names nothing gets foundation and nothing else', () {
      expect(_pathsOf(found.selected(const <String>[])), <String>['foundation']);
    });

    test('a project gets foundation on top of what it named', () {
      expect(
        _pathsOf(found.selected(const <String>['security/auth'])),
        <String>['foundation', 'security/auth'],
      );
    });

    test('naming a module never drags a neighbour in with it', () {
      expect(
        _pathsOf(found.selected(const <String>['security/rbac'])),
        <String>['foundation', 'security/rbac'],
        reason: 'rbac is written against auth, and says so at the endpoint rather than here',
      );
    });

    test('naming a module that does not exist fails and lists the ones that do', () {
      expect(
        () => found.selected(const <String>['security/nope']),
        throwsA(
          isA<Exception>().having(
            (Exception error) => error.toString(),
            'message',
            allOf(contains('security/nope'), contains('security/auth')),
          ),
        ),
      );
    });
  });

  group('what a module ships', () {
    test('the sql it adds is the db/init it carries', () {
      final Directory owned = _root('dependencies');
      final Directory module = _module(owned, 'security/auth');
      module.childDirectory('db').childDirectory('init').createSync(recursive: true);
      module.childDirectory('db').childDirectory('migrations').createSync(recursive: true);

      expect(
        Dependencies.load(roots: <Directory>[owned]).all.single.sql?.path,
        module.childDirectory('db').childDirectory('init').path,
      );
    });

    test('a module without a db directory adds no sql', () {
      final Directory owned = _root('dependencies');
      _module(owned, 'security/rbac');

      expect(Dependencies.load(roots: <Directory>[owned]).all.single.sql, isNull);
    });

    test('its profiles are the ones its compose fragment names', () {
      final Directory owned = _root('dependencies');
      _compose(_module(owned, 'features/searcher'), '  opensearch:\n    profiles: ["search"]\n');

      expect(Dependencies.load(roots: <Directory>[owned]).all.single.profiles, <String>{'search'});
    });

    test('a profile written as a block list is read too', () {
      final Directory owned = _root('dependencies');
      _compose(_module(owned, 'security/vpn'), '  vpn-admins:\n    profiles:\n      - ops\n');

      expect(Dependencies.load(roots: <Directory>[owned]).all.single.profiles, <String>{'ops'});
    });

    test('a module whose services name no profile always starts them', () {
      final Directory owned = _root('dependencies');
      _compose(_module(owned, 'security/auth'), '  auth:\n    image: "gotrue"\n');

      expect(Dependencies.load(roots: <Directory>[owned]).all.single.profiles, isEmpty);
    });

    test('a profile is named once however many services sit behind it', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _compose(
        _module(packages, 'realtime'),
        '  realtime:\n    profiles: ["realtime"]\n  realtime-init:\n    profiles: ["realtime"]\n',
      );
      _compose(_module(owned, 'features/searcher'), '  opensearch:\n    profiles: ["search"]\n');

      final Dependencies found = Dependencies.load(roots: <Directory>[owned, packages]);

      expect(Dependencies.profilesOf(found.all), <String>['realtime', 'search']);
    });
  });
}
