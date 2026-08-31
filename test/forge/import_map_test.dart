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

import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/forge/import_map.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:test/test.dart';

const Map<String, dynamic> _mixedFramework = <String, dynamic>{
  'imports': <String, dynamic>{
    'ioredis': 'npm:ioredis@5',
    '@std/assert': 'jsr:@std/assert@1',
    '@scribe/alchemy': './alchemy/mod.ts',
    '@scribe/search': './packages/search/lib/search.ts',
    '@scribe/search/testing': './packages/search/tests/testing/testing.ts',
    '@scribe/sdk': './sdk/js/mod.ts',
    '@scribe/protocol/': './protocol/',
  },
};

late MemoryFileSystem fs;

const String checkout = '/work/notes/scribe';

Future<T> _run<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs, Logger: BufferLogger.new}, body: body);

void _package(String name, {String at = '$checkout/packages', Map<String, String>? opens}) {
  final Directory directory = fs.directory('$at/$name')..createSync(recursive: true);
  directory.childDirectory('protocol').createSync();
  directory
      .childFile('deno.json')
      .writeAsStringSync(
        jsonEncode(<String, Object>{
          'imports': <String, String>{'@scribe/$name': './lib/$name.ts', ...?opens},
        }),
      );
}

/// A package the way every one this checkout ships actually looks: no `deno.json`
/// of its own, its doors carried instead in the checkout's own map.
void _shippedPackage(String name) {
  fs.directory('$checkout/packages/$name/protocol').createSync(recursive: true);
}

void _project(List<String> wanted, {Map<String, String> from = const <String, String>{}}) {
  final StringBuffer text = StringBuffer('name: "notes"\ndependencies:\n');
  for (final String name in wanted) {
    final String? path = from[name];
    text.write(path == null ? '  - $name\n' : '  - $name:\n      path: $path\n');
  }
  fs.file('/work/notes/config.yaml').writeAsStringSync(text.toString());
}

Future<Map<String, String>> _doors({Map<String, dynamic> framework = const <String, dynamic>{}}) =>
    _run(() => mountedDoors(fs.directory(checkout), framework, Packages.load()));

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
    fs.currentDirectory = '/work/notes';
    _project(const <String>[]);
  });

  test('a mounted package opens the doors its own map names', () async {
    _package('foundation', opens: <String, String>{'@scribe/foundation/queue': './lib/queue.ts'});
    _project(const <String>['foundation']);

    expect(await _doors(), <String, String>{
      '@scribe/foundation': 'packages/foundation/lib/foundation.ts',
      '@scribe/foundation/queue': 'packages/foundation/lib/queue.ts',
    });
  });

  test('a specifier ending in a slash keeps one, since Deno nulls a target without it', () async {
    _package('foundation', opens: <String, String>{'@scribe/foundation/': './'});
    _project(const <String>['foundation']);

    expect((await _doors())['@scribe/foundation/'], 'packages/foundation/');
  });

  test('a package the checkout does not carry opens its doors the same way', () async {
    _package('billing', at: '/work/billing');
    _project(const <String>['billing'], from: const <String, String>{'billing': '../billing/billing'});

    expect((await _doors())['@scribe/billing'], '/work/billing/billing/lib/billing.ts');
  });

  test('a door outside the checkout keeps an absolute path, one inside stays relative', () async {
    _package('foundation');
    _package('billing', at: '/work/billing');
    _project(const <String>['foundation', 'billing'], from: const <String, String>{'billing': '../billing/billing'});

    final Map<String, String> doors = await _doors();

    expect(doors['@scribe/foundation'], isNot(startsWith('/')));
    expect(doors['@scribe/billing'], startsWith('/'));
  });

  test('a package that is not mounted opens nothing', () async {
    _package('auth');
    _project(const <String>[]);

    expect((await _doors()).keys.where((String k) => k.startsWith('@scribe/auth')), isEmpty);
  });

  test('a map naming another package is left alone, so a door has one owner', () async {
    _package('auth', opens: <String, String>{'@scribe/foundation/queue': '../foundation/lib/queue.ts'});
    _project(const <String>['auth']);

    expect((await _doors()).containsKey('@scribe/foundation/queue'), isFalse);
  });

  test('the language comes from the framework map, relative to the checkout', () async {
    final Map<String, String> doors = await _doors(
      framework: <String, dynamic>{
        'imports': <String, dynamic>{'@scribe/alchemy': './alchemy/mod.ts', 'ioredis': 'npm:ioredis@5'},
      },
    );

    expect(doors, containsPair('@scribe/alchemy', 'alchemy/mod.ts'));
  });

  test('a dependency that is not a path is left out, since it names no file here', () async {
    final Map<String, String> doors = await _doors(
      framework: <String, dynamic>{
        'imports': <String, dynamic>{'ioredis': 'npm:ioredis@5'},
      },
    );

    expect(doors, isEmpty);
  });

  group('a package this checkout carries in its own map, the way every one ships today', () {
    const Map<String, dynamic> framework = <String, dynamic>{
      'imports': <String, dynamic>{
        '@scribe/foundation': './packages/foundation/lib/foundation.ts',
        '@scribe/foundation/queue': './packages/foundation/lib/queue.ts',
        '@scribe/auth': './packages/auth/lib/auth.ts',
      },
    };

    test('opens nothing for a package that is not mounted', () async {
      _shippedPackage('foundation');
      _shippedPackage('auth');
      _project(const <String>['foundation']);

      final Map<String, String> doors = await _doors(framework: framework);

      expect(doors.keys.where((String k) => k.startsWith('@scribe/auth')), isEmpty);
    });

    test('opens every door of a package that is mounted', () async {
      _shippedPackage('foundation');
      _shippedPackage('auth');
      _project(const <String>['foundation']);

      final Map<String, String> doors = await _doors(framework: framework);

      expect(doors, containsPair('@scribe/foundation', 'packages/foundation/lib/foundation.ts'));
      expect(doors, containsPair('@scribe/foundation/queue', 'packages/foundation/lib/queue.ts'));
    });
  });

  group('inheritedImports', () {
    test('keeps only what is not a path inside the checkout', () {
      expect(inheritedImports(_mixedFramework), <String, String>{
        'ioredis': 'npm:ioredis@5',
        '@std/assert': 'jsr:@std/assert@1',
      });
    });

    test('drops a package door even when mountedDoors would grant it separately', () {
      final Map<String, String> inherited = inheritedImports(_mixedFramework);

      expect(inherited.keys.where((String k) => k.startsWith('@scribe/search')), isEmpty);
    });

    test('drops the framework path aliases too, path or not', () {
      final Map<String, String> inherited = inheritedImports(_mixedFramework);

      expect(inherited, isNot(contains('@scribe/sdk')));
      expect(inherited, isNot(contains('@scribe/protocol/')));
    });
  });

  group('renderImportMap', () {
    Map<String, dynamic> renderedImports({Map<String, String> sourceRoots = const <String, String>{}}) {
      final Map<String, dynamic> document =
          jsonDecode(
                renderImportMap(
                  _mixedFramework,
                  const <String, String>{},
                  frameworkRoot: '/work/notes/scribe/',
                  libRoot: '/work/notes/lib/',
                  assetsRoot: '/work/notes/assets/',
                  sourceRoots: sourceRoots,
                  doors: const <String, String>{},
                ),
              )
              as Map<String, dynamic>;

      return document['imports'] as Map<String, dynamic>;
    }

    test('@app/ answers for the lib root, and nothing else does by default', () async {
      await _run(() {
        expect(renderedImports()['@app/'], '/work/notes/lib/');
        expect(renderedImports().keys, isNot(contains('@services/')));
      });
    });

    test('a source root opens an alias of its own name, next to @app/', () async {
      await _run(() {
        final Map<String, dynamic> imports = renderedImports(
          sourceRoots: const <String, String>{'services': '/work/notes/services/'},
        );

        expect(imports['@services/'], '/work/notes/services/');
        expect(imports['@app/'], '/work/notes/lib/');
      });
    });

    test('several source roots each open their own alias', () async {
      await _run(() {
        final Map<String, dynamic> imports = renderedImports(
          sourceRoots: const <String, String>{'services': '/work/notes/services/', 'jobs': '/work/notes/jobs/'},
        );

        expect(imports['@services/'], '/work/notes/services/');
        expect(imports['@jobs/'], '/work/notes/jobs/');
      });
    });
  });
}
