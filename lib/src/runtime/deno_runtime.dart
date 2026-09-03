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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:scribe_tools/src/runtime/editor_projection.dart';

/// The permissions a package's own suite runs under, and nothing more.
///
/// The four are what the framework grants its own suite. Reading the environment is what an npm
/// dependency does the moment it loads, reading the system is what a runtime probe does, and
/// reading files is what the runtime does to reach the package at all. Writing is what a driver
/// that puts a file on disk does. Nothing here reaches the network: a test that needs the stack up
/// is an end-to-end test, run against a stack rather than from here.
const List<String> kTestPermissions = <String>['--allow-env', '--allow-sys', '--allow-read', '--allow-write'];

/// `JsRuntime.runScript`'s Deno implementation: an `--import-map` built from [imports].
Future<ShellResult> runScript(
  String scriptPath, {
  required List<String> scriptArgs,
  required Map<String, String> imports,
  String? cwd,
}) {
  DenoCmd command = Deno.run().allowRead().importMap(_importMap(imports)).file(scriptPath);
  for (final String arg in scriptArgs) {
    command = command.scriptArg(arg);
  }

  return command.output(cwd: cwd);
}

/// `JsRuntime.testCommand`'s Deno implementation: `deno test --import-map <...>`.
List<String> testCommand({required String testsDirectory, required Map<String, String> imports, String? filter}) {
  DenoCmd command = Deno.test().importMap(_importMap(imports));
  for (final String permission in kTestPermissions) {
    command = command.token(permission);
  }
  if (filter != null) command = command.filter(filter);
  command = command.file(testsDirectory);

  return commandArgv(command);
}

/// [imports], as the `data:` URL a `--import-map` flag takes directly.
///
/// No file is written for `deno` to read: the value carries the whole map, so nothing has to
/// survive on disk for this one invocation, and nothing has to be cleaned up after it either.
String _importMap(Map<String, String> imports) =>
    'data:application/json;base64,${base64Encode(utf8.encode(jsonEncode(<String, Object>{'imports': imports})))}';

/// `JsRuntime.editorProjection`'s Deno implementation: an import map, and the settings the
/// `denoland.vscode-deno` extension needs to enable itself and read it.
///
/// `deno.enablePaths` is set to [directories] rather than left out, so that a workspace holding
/// packages of more than one runtime does not have Deno's language server take over directories a
/// `bun` package lives in.
EditorProjection editorProjection(Map<String, String> imports, {required List<String> directories}) =>
    EditorProjection(
      languageServer: LanguageServerProjection(
        runtime: 'deno',
        extensionId: 'denoland.vscode-deno',
        enableSettingKey: 'deno.enable',
        configSettingKey: 'deno.config',
        additionalSettings: <String, Object>{'deno.enablePaths': directories},
        configFileName: 'deno.json',
        configContents: '${jsonEncode(<String, Object>{'imports': imports})}\n',
        restartCommands: const <String>['deno.client.restart', 'deno.restart'],
      ),
    );
