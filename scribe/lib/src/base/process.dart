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

import 'dart:io' as io;

/// Every external command this tool runs.
///
/// A command is an argument list, never a shell line: nothing is quoted,
/// nothing is expanded, and no shell has to be installed. There is therefore
/// nothing to escape and no way to inject a second command through an argument.
abstract class ProcessRunner {
  const ProcessRunner();

  /// Runs [command], letting it write to this process's streams, and returns its status.
  Future<int> run(List<String> command, {String? workingDirectory});

  /// Runs [command] and returns what it wrote on standard output.
  ///
  /// Standard error is dropped, and the status is not looked at: a command that
  /// failed comes back as an empty string.
  Future<String> capture(List<String> command, {String? workingDirectory});
}

/// The [ProcessRunner] that starts real processes.
class LocalProcessRunner extends ProcessRunner {
  const LocalProcessRunner();

  @override
  Future<int> run(List<String> command, {String? workingDirectory}) async {
    final io.Process process = await io.Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      mode: io.ProcessStartMode.inheritStdio,
    );

    return process.exitCode;
  }

  @override
  Future<String> capture(List<String> command, {String? workingDirectory}) async {
    final io.ProcessResult result = await io.Process.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
    );

    return '${result.stdout}';
  }
}

/// A [ProcessRunner] that starts nothing and remembers what it was asked to run.
///
/// Every call answers the same [exitCode] and [output]; [commands] is what a
/// test asserts on.
class RecordingProcessRunner extends ProcessRunner {
  RecordingProcessRunner({this.exitCode = 0, this.output = ''});

  /// The status every call answers.
  final int exitCode;

  /// The text every [capture] answers.
  final String output;

  /// The commands this runner was handed, in the order they arrived.
  final List<List<String>> commands = <List<String>>[];

  @override
  Future<int> run(List<String> command, {String? workingDirectory}) async {
    commands.add(command);
    return exitCode;
  }

  @override
  Future<String> capture(List<String> command, {String? workingDirectory}) async {
    commands.add(command);
    return output;
  }
}
