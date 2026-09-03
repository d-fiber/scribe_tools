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

import 'package:scribe_tools/src/runtime/deno_runtime.dart' as deno_runtime;
import 'package:scribe_tools/src/runtime/editor_projection.dart';
import 'package:test/test.dart';

void main() {
  test('without a filter, the command carries the four permissions and the tests directory', () {
    final List<String> command = deno_runtime.testCommand(testsDirectory: 'tests', imports: const <String, String>{});

    expect(command.first, 'deno');
    expect(command[1], 'test');
    expect(command[2], '--import-map');
    for (final String permission in deno_runtime.kTestPermissions) {
      expect(command, contains(permission));
    }
    expect(command, isNot(contains('--filter')));
    expect(command.last, 'tests');
  });

  test('a filter is passed as --filter, before the tests directory', () {
    final List<String> command = deno_runtime.testCommand(
      testsDirectory: 'tests',
      imports: const <String, String>{},
      filter: 'reads a file',
    );

    final int flag = command.indexOf('--filter');
    expect(flag, isNonNegative);
    expect(command[flag + 1], 'reads a file');
    expect(command.last, 'tests');
  });

  group('editorProjection', () {
    test('carries an import map and the two deno.* settings a language server needs', () {
      final EditorProjection projection = deno_runtime.editorProjection(
        const <String, String>{'@scribe/alchemy': 'file:///alchemy/mod.ts'},
        directories: <String>['/pkg/one', '/pkg/two'],
      );

      final LanguageServerProjection? server = projection.languageServer;
      expect(server, isNotNull);
      expect(server!.runtime, 'deno');
      expect(server.extensionId, 'denoland.vscode-deno');
      expect(server.enableSettingKey, 'deno.enable');
      expect(server.configSettingKey, 'deno.config');
      expect(server.additionalSettings, <String, Object>{
        'deno.enablePaths': <String>['/pkg/one', '/pkg/two'],
      });
      expect(server.configFileName, 'deno.json');
      expect(server.restartCommands, <String>['deno.client.restart', 'deno.restart']);
      expect(projection.filesWritten, isEmpty, reason: 'the caller writes deno.json, not this runtime');

      final Map<String, Object?> decoded = jsonDecode(server.configContents) as Map<String, Object?>;
      expect(decoded, <String, Object?>{
        'imports': <String, Object?>{'@scribe/alchemy': 'file:///alchemy/mod.ts'},
      });
    });
  });
}
