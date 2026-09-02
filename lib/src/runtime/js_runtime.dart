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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/runtime/bun_runtime.dart' as bun_runtime;
import 'package:scribe_tools/src/runtime/deno_runtime.dart' as deno_runtime;
import 'package:scribe_tools/src/tools.dart';

/// One JS runtime a package's own tooling can run its TypeScript on.
///
/// This is the one place a new runtime is added: a case here, [tool] naming what `scribe doctor`
/// checks for, and the two switches in [runScript] and [testCommand] naming the module that knows
/// how this runtime is actually invoked. Nothing outside `runtime/` names `deno` or `bun` as a
/// literal string — [named] is how a manifest's `environment.runtime:` becomes one of these, and
/// every caller reaches a runtime through it or through this enum's values, never by writing the
/// word itself.
enum JsRuntime {
  /// The framework's own runtime, and the default when a manifest names none.
  deno(ToolCatalog.deno),

  /// The second runtime a package may opt into, under `environment.runtime: bun`.
  bun(ToolCatalog.bun);

  const JsRuntime(this.tool);

  /// What `scribe doctor` checks for and offers to install.
  final ExternalTool tool;

  /// The runtime a manifest names `named`, refusing one this tool does not know.
  static JsRuntime named(String named) => JsRuntime.values.firstWhere(
    (JsRuntime runtime) => runtime.name == named,
    orElse: () => throwToolExit(
      '"$named" is not a runtime this tool knows. Write one of: '
      '${JsRuntime.values.map((JsRuntime runtime) => runtime.name).join(', ')}.',
    ),
  );

  /// Runs [scriptPath] with [scriptArgs], resolving `@scribe/...` specifiers against [imports], and
  /// answers what it printed.
  ///
  /// [imports] is a plain specifier-to-address map, the shape every runtime's own resolution
  /// mechanism is built from — `deno_runtime.dart` turns it into an `--import-map`,
  /// `bun_runtime.dart` into a generated `tsconfig.json`, because neither speaks the other's
  /// format.
  Future<ShellResult> runScript(
    String scriptPath, {
    required List<String> scriptArgs,
    required Map<String, String> imports,
    String? cwd,
  }) => switch (this) {
    JsRuntime.deno => deno_runtime.runScript(scriptPath, scriptArgs: scriptArgs, imports: imports, cwd: cwd),
    JsRuntime.bun => bun_runtime.runScript(scriptPath, scriptArgs: scriptArgs, imports: imports, cwd: cwd),
  };

  /// The command line that runs the suite under [testsDirectory], resolving specifiers against
  /// [imports], keeping to [filter] when it is given.
  List<String> testCommand({required String testsDirectory, required Map<String, String> imports, String? filter}) =>
      switch (this) {
        JsRuntime.deno => deno_runtime.testCommand(testsDirectory: testsDirectory, imports: imports, filter: filter),
        JsRuntime.bun => bun_runtime.testCommand(testsDirectory: testsDirectory, imports: imports, filter: filter),
      };
}
