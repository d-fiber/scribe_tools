// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

/// The name this tool is invoked by, and the name it signs generated files with.
const String kToolName = 'scribe';

/// A failure the user is meant to read, rather than a bug to report.
///
/// The runner catches it, prints [message] and leaves with [exitCode], so no
/// code below it has to decide how the process ends.
final class ToolExit implements Exception {
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
