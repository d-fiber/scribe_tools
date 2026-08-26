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
import 'package:scribe_tools/src/commands/gen/code/generators/config/import_map.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:test/test.dart';

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
}
