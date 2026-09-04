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
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runtime/bun_runtime.dart' as bun_runtime;
import 'package:scribe_tools/src/runtime/editor_projection.dart';
import 'package:test/test.dart';

Future<T> _run<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: MemoryFileSystem.test}, body: body);

void main() {
  test('without a filter, the command names the tests directory and nothing else after it', () {
    _run(() {
      final List<String> command = bun_runtime.testCommand(testsDirectory: 'tests', imports: const <String, String>{});

      expect(command.first, 'bun');
      expect(command[1], 'test');
      expect(command[2], startsWith('--tsconfig-override='));
      expect(command.last, 'tests');
      expect(command, isNot(contains('-t')));
      expect(command, hasLength(4), reason: 'nothing sits between the tsconfig flag and the tests directory');
    });
  });

  test('a filter is passed as --test-name-pattern, before the tests directory', () {
    _run(() {
      final List<String> command = bun_runtime.testCommand(
        testsDirectory: 'tests',
        imports: const <String, String>{},
        filter: 'reads a file',
      );

      expect(command, contains('--test-name-pattern=reads a file'));
      expect(command.last, 'tests');
    });
  });

  group('editorProjection', () {
    test('writes a tsconfig.json under each directory, and configures no language server', () {
      _run(() {
        globals.fs.directory('/pkg/one').createSync(recursive: true);
        globals.fs.directory('/pkg/two').createSync(recursive: true);

        final EditorProjection projection = bun_runtime.editorProjection(
          const <String, String>{'@scribe/alchemy': 'file:///alchemy/mod.ts', '@scribe/foo/': 'file:///foo/lib/'},
          directories: <String>['/pkg/one', '/pkg/two'],
        );

        expect(projection.languageServer, isNull);
        expect(projection.filesWritten, <String>['/pkg/one/tsconfig.json', '/pkg/two/tsconfig.json']);

        for (final String written in projection.filesWritten) {
          final Map<String, Object?> decoded =
              jsonDecode(globals.fs.file(written).readAsStringSync()) as Map<String, Object?>;
          final Map<String, Object?> options = decoded['compilerOptions']! as Map<String, Object?>;
          expect(options['baseUrl'], '.');
          final Map<String, Object?> paths = options['paths']! as Map<String, Object?>;
          expect(paths['@scribe/alchemy'], <String>['/alchemy/mod.ts']);
          expect(paths['@scribe/foo/*'], <String>['/foo/lib/*']);
        }
      });
    });
  });
}
