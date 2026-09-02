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

/// `bun`, built the same way `fiber_shell` builds `deno`: a thin, chainable wrapper naming only
/// the flags this tool actually reaches for.
///
/// `fiber_shell` does not ship this one — `CommandBuilder<T>` is generic and reusable on its own,
/// so this lives here instead of asking that package to carry a wrapper only this CLI calls today.
class BunCmd extends CommandBuilder<BunCmd> {
  @override
  final String executable = 'bun';

  /// Runs a script or a package script (`bun run`).
  BunCmd run() => token('run');

  /// Runs the test suite (`bun test`).
  BunCmd test() => token('test');

  /// Resolves `@scribe/...` specifiers from this `tsconfig.json` instead of `$cwd/tsconfig.json`.
  BunCmd tsconfigOverride(String path) => joined('--tsconfig-override', path);

  /// Runs only the tests whose name matches this pattern (`-t`).
  BunCmd testNamePattern(String pattern) => pair('-t', pattern);

  /// The module to run, a path or a package script name.
  BunCmd file(String path) => token(path);

  /// Adds an argument for the script, landing in its own `process.argv`.
  BunCmd scriptArg(String value) => token(value);
}

/// `bun`, ready to take its subcommand.
// ignore: non_constant_identifier_names
BunCmd get Bun => BunCmd();
