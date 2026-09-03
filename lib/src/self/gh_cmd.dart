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

/// `gh`, the GitHub CLI, built the same way `fiber_shell` builds `git`: a thin, chainable wrapper
/// naming only the flags this tool actually reaches for.
///
/// `fiber_shell` does not ship this one, the same reason `BunCmd` lives beside the runtime that
/// calls it rather than in that package: a wrapper only this codebase's `self/` update checks
/// reach for, as the fallback `curl` takes when it is missing, stays here instead.
class GhCmd extends CommandBuilder<GhCmd> {
  @override
  final String executable = 'gh';

  /// Calls a raw GitHub API path (`api`).
  GhCmd api() => token('api');

  /// Manages releases (`release`).
  GhCmd release() => token('release');

  /// Downloads the assets of a release (`download`). The subcommand of [release].
  GhCmd download() => token('download');

  /// The repository a call answers for, `owner/name` (`--repo`).
  GhCmd repo(String value) => pair('--repo', value);

  /// Only the assets whose name matches this glob (`--pattern`).
  GhCmd pattern(String value) => pair('--pattern', value);

  /// Where a download is written (`--output`).
  GhCmd outputFile(String path) => pair('--output', path);

  /// Overwrites a file already at the output path (`--clobber`).
  GhCmd clobber() => token('--clobber');

  /// A `jq` expression narrowing a JSON response (`-q`).
  GhCmd query(String expression) => pair('-q', expression);

  /// Adds a bare argument: the API path `api` reads, or anything else this wrapper has no
  /// named option for.
  GhCmd arg(String value) => token(value);
}

/// `gh`, ready to take its first subcommand.
// ignore: non_constant_identifier_names
GhCmd get Gh => GhCmd();
