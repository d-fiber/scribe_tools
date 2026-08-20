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

/// The name this tool is invoked by, and the name it signs generated files with.
const String kToolName = 'scribe';

/// A failure the user is meant to read, rather than a bug to report.
///
/// The runner catches it, prints [message] and leaves with [exitCode], so no
/// code below it has to decide how the process ends.
final class ToolExit implements Exception {
  /// Fails with [message], leaving with [exitCode].
  const ToolExit(this.message, {this.exitCode = 1});

  /// What went wrong, or null to leave without a word.
  final String? message;

  /// The status the process leaves with.
  final int exitCode;

  @override
  String toString() => message ?? 'ToolExit';
}

/// Throws a [ToolExit] carrying [message] and [exitCode].
Never throwToolExit(String? message, {int exitCode = 1}) {
  throw ToolExit(message, exitCode: exitCode);
}

/// A command called the wrong way: an option missing, a value that does not parse.
///
/// The runner prints [message] and leaves with the status reserved for a usage
/// mistake, which is not the one a [ToolExit] uses.
final class UsageError implements Exception {
  /// Refuses the call with [message], naming [command] when one was reached.
  const UsageError(this.message, {this.command});

  /// What the user got wrong, and what to write instead.
  final String message;

  /// The command the mistake was made on, when one had been reached.
  final String? command;

  @override
  String toString() => message;
}

/// Throws a [UsageError] carrying [message], blamed on [command].
Never throwUsageError(String message, {String? command}) {
  throw UsageError(message, command: command);
}
