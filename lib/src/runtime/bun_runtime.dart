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
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runtime/editor_projection.dart';

/// `JsRuntime.runScript`'s Bun implementation: a generated `tsconfig.json`, read with
/// `--tsconfig-override`.
///
/// Bun has no `--import-map` of its own; `dev_tools/resolution/bun/generate.sh` already proved the
/// shape a `tsconfig.json` needs for `@scribe/...` specifiers to resolve the same way under Bun as
/// under Deno, and this follows it, built from [imports] instead of the checkout's fixed
/// `scribe.imports.json`.
Future<ShellResult> runScript(
  String scriptPath, {
  required List<String> scriptArgs,
  required Map<String, String> imports,
  String? cwd,
}) async {
  final File tsconfig = _writeTsconfig(imports);
  try {
    BunCmd command = Bun.run().tsconfigOverride(tsconfig.path).arg(scriptPath);
    for (final String arg in scriptArgs) {
      command = command.arg(arg);
    }

    return await command.output(cwd: cwd);
  } finally {
    tsconfig.parent.deleteSync(recursive: true);
  }
}

/// `JsRuntime.testCommand`'s Bun implementation: `bun test --tsconfig-override <...>`.
///
/// The `tsconfig.json` this writes is never cleaned up by the caller of this command line the way
/// [runScript] cleans up its own: whoever runs the returned command line owns the process, and
/// deleting the file out from under a `bun test` still reading it would be worse than leaving one
/// small file behind in a temporary directory the host already reclaims on its own.
///
/// Built through [BunCmd], the same builder [runScript] chains above, rather than a hand-assembled
/// list: the two would otherwise be free to drift on the flags Bun actually takes.
List<String> testCommand({required String testsDirectory, required Map<String, String> imports, String? filter}) {
  final File tsconfig = _writeTsconfig(imports);

  BunCmd command = Bun.test().tsconfigOverride(tsconfig.path);
  if (filter != null) command = command.testNamePattern(filter);
  command = command.arg(testsDirectory);

  return commandArgv(command);
}

/// `JsRuntime.editorProjection`'s Bun implementation: a real `tsconfig.json`, one under each of
/// [directories], read by a stock TypeScript language server on its own.
///
/// Bun has no editor extension of its own to point at anything; a stock TypeScript language
/// server already resolves `@scribe/...` the moment it finds a `tsconfig.json` walking up from an
/// open file, which is why this writes a persistent file at the root of every package instead of
/// the temporary one [runScript] and [testCommand] write and clean up around a single invocation
/// — `.scribe/` sits beside `lib/`, not above it, so a config written there would never be found
/// that way. Nothing is returned for [EditorProjection.languageServer]: there is nothing for an
/// editor to configure, the file already written is enough.
EditorProjection editorProjection(Map<String, String> imports, {required List<String> directories}) {
  final String contents = _tsconfigContents(imports);
  final List<String> written = <String>[
    for (final String directory in directories)
      (globals.fs.file(p.join(directory, 'tsconfig.json'))..writeAsStringSync(contents)).path,
  ];

  return EditorProjection(filesWritten: written);
}

/// A `tsconfig.json`, in a temporary directory of its own, whose `paths` resolve [imports] the way
/// Bun's module loader reads them.
File _writeTsconfig(Map<String, String> imports) {
  final Directory scratch = globals.fs.systemTempDirectory.createTempSync('scribe-bun-');
  return scratch.childFile('tsconfig.json')..writeAsStringSync(_tsconfigContents(imports));
}

/// The `tsconfig.json` contents whose `paths` resolve [imports] the way Bun's module loader reads
/// them, shared by the temporary file [_writeTsconfig] writes and the persistent one
/// [editorProjection] writes.
///
/// An `npm:` or a `jsr:` address is left out, the same as `generate.sh` leaves them out: Bun
/// resolves those through its own `node_modules`-style lookup, and a `paths` entry for one would
/// only shadow it. A folder specifier, one ending in `/`, becomes a glob pair, `"key/*": ["address/*"]`;
/// a bare one becomes `"key": ["address"]`. Every address arrives as a `file://` URL — the same
/// shape `deno`'s own import map carries — and is turned back into a plain filesystem path, since
/// a `tsconfig.json` `paths` entry does not read a URL.
String _tsconfigContents(Map<String, String> imports) {
  final Map<String, List<String>> paths = <String, List<String>>{};

  for (final MapEntry<String, String> entry in imports.entries) {
    if (entry.value.startsWith('npm:') || entry.value.startsWith('jsr:')) continue;

    final String address = _asFilePath(entry.value);
    if (entry.key.endsWith('/')) {
      paths['${entry.key}*'] = <String>['$address*'];
    } else {
      paths[entry.key] = <String>[address];
    }
  }

  return jsonEncode(<String, Object>{
    'compilerOptions': <String, Object>{'baseUrl': '.', 'paths': paths},
  });
}

/// [address] as a filesystem path, unwrapped from the `file://` URL it carries.
///
/// An import map never holds anything else: every entry that survives to here came from
/// `sdkImports` or a package door, and both spell an address as `Uri.file`/`Uri.directory` already
/// does.
String _asFilePath(String address) => Uri.parse(address).toFilePath();
