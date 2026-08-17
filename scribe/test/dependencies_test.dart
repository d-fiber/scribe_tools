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
import 'package:scribe/src/dependencies.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

/// Writes a `scribe.yaml` for [name] at [path] under [root].
void _module(Directory root, String path, String name) {
  final Directory directory = root.childDirectory(path)..createSync(recursive: true);
  directory.childFile('scribe.yaml').writeAsStringSync('''
name: $name
title: A module.
optional: true

requires: []

sql: null
protocol: null
export: ./$name

routes: []
''');
}

Directory _root(String name) => fs.directory(p.join('/tree', name))..createSync(recursive: true);

List<String> _pathsOf(Dependencies found) =>
    found.all.map((Dependency dependency) => dependency.path).toList();

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  group('the two dependency roots', () {
    test('a module is addressed relative to the root that carries it', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest', 'rest');
      _module(packages, 'security/auth', 'auth');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, packages])),
        <String>['database/rest', 'security/auth'],
      );
    });

    test('a module keeps its address when it moves from one root to the other', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'security/auth', 'auth');

      final String before = Dependencies.load(roots: <Directory>[owned, packages]).all.single.path;

      owned.childDirectory('security').deleteSync(recursive: true);
      _module(packages, 'security/auth', 'auth');

      final String after = Dependencies.load(roots: <Directory>[owned, packages]).all.single.path;

      expect(after, before);
      expect(after, 'security/auth');
    });

    test('the modules of both roots are merged into one sorted list', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest', 'rest');
      _module(packages, 'features/searcher', 'searcher');
      _module(packages, 'database/storage', 'storage');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, packages])),
        <String>['database/rest', 'database/storage', 'features/searcher'],
      );
    });

    test('a root that does not exist yields nothing rather than failing', () {
      final Directory owned = _root('dependencies');
      _module(owned, 'database/rest', 'rest');

      expect(
        _pathsOf(Dependencies.load(roots: <Directory>[owned, fs.directory('/tree/packages')])),
        <String>['database/rest'],
      );
    });

    test('byPath finds a module whichever root carries it', () {
      final Directory owned = _root('dependencies');
      final Directory packages = _root('packages');
      _module(owned, 'database/rest', 'rest');
      _module(packages, 'security/auth', 'auth');

      final Dependencies found = Dependencies.load(roots: <Directory>[owned, packages]);

      expect(found.byPath('security/auth')?.name, 'auth');
      expect(found.byPath('database/rest')?.name, 'rest');
    });
  });
}
