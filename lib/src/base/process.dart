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

import 'dart:io' as io;

/// Every external command this tool runs.
///
/// A command is an argument list, never a shell line: nothing is quoted,
/// nothing is expanded, and no shell has to be installed. There is therefore
/// nothing to escape and no way to inject a second command through an argument.
abstract class ProcessRunner {
  /// Holds nothing, so every runner can be a constant.
  const ProcessRunner();

  /// Runs [command], letting it write to this process's streams, and returns its status.
  ///
  /// [environment] is added to what this process already carries, and never
  /// replaces it: a tool that needs a variable of its own still needs the PATH
  /// that found it.
  Future<int> run(List<String> command, {String? workingDirectory, Map<String, String>? environment});

  /// Runs [command] and returns what it wrote on standard output.
  ///
  /// Standard error is dropped, and the status is not looked at: a command that
  /// failed comes back as an empty string.
  Future<String> capture(List<String> command, {String? workingDirectory});

  /// Runs [command] holding on to everything it wrote, and to how it ended.
  ///
  /// It is what a caller uses when a tool is noisy on the way to succeeding and
  /// its noise is only worth showing when it fails.
  Future<ProcessOutcome> observe(List<String> command, {String? workingDirectory, Map<String, String>? environment});

  /// [observe], blocking instead of awaiting.
  ///
  /// It exists for a caller that cannot itself be async without spreading that
  /// across everything that reaches it: resolving a package's dependencies walks
  /// a manifest by ordinary recursion, and a git dependency has to run inside
  /// that same walk rather than turn it, and every command that reads what it
  /// resolved, into one that awaits.
  ProcessOutcome observeSync(List<String> command, {String? workingDirectory, Map<String, String>? environment});

  /// Starts [command] and forgets it, without waiting for it to end.
  ///
  /// The child outlives this process and writes nowhere it could be seen. It is
  /// how the version check reaches the network without the command the user
  /// typed ever waiting on it.
  void detach(List<String> command, {String? workingDirectory});
}

/// What a process wrote, and how it ended.
class ProcessOutcome {
  /// Holds the [exitCode] a process ended on and the two streams it wrote.
  const ProcessOutcome({required this.exitCode, required this.stdout, required this.stderr});

  /// The status the process ended on, zero when it did what it was asked.
  final int exitCode;

  /// Everything it wrote on standard output.
  final String stdout;

  /// Everything it wrote on standard error.
  final String stderr;

  /// Whether the process did what it was asked.
  bool get succeeded => exitCode == 0;
}

/// The [ProcessRunner] that starts real processes.
class LocalProcessRunner extends ProcessRunner {
  /// Starts real processes.
  const LocalProcessRunner();

  @override
  Future<int> run(List<String> command, {String? workingDirectory, Map<String, String>? environment}) async {
    final io.Process process = await io.Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      environment: environment,
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

  @override
  Future<ProcessOutcome> observe(
    List<String> command, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final io.ProcessResult result = await io.Process.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      environment: environment,
    );

    return ProcessOutcome(exitCode: result.exitCode, stdout: '${result.stdout}', stderr: '${result.stderr}');
  }

  @override
  ProcessOutcome observeSync(List<String> command, {String? workingDirectory, Map<String, String>? environment}) {
    final io.ProcessResult result = io.Process.runSync(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      environment: environment,
    );

    return ProcessOutcome(exitCode: result.exitCode, stdout: '${result.stdout}', stderr: '${result.stderr}');
  }

  @override
  void detach(List<String> command, {String? workingDirectory}) {
    io.Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      mode: io.ProcessStartMode.detached,
    ).ignore();
  }
}

/// A [ProcessRunner] that starts nothing and remembers what it was asked to run.
///
/// Every call answers the same [exitCode] and [output]; [commands] is what a
/// test asserts on.
class RecordingProcessRunner extends ProcessRunner {
  /// Answers [exitCode] and [output] to everything, [outputs] taking over per command.
  RecordingProcessRunner({this.exitCode = 0, this.output = '', this.outputs = const <String, String>{}});

  /// The status every call answers.
  final int exitCode;

  /// The text every [capture] answers, unless [outputs] carries the command.
  final String output;

  /// What [capture] answers, keyed by a word the command carries.
  ///
  /// It is how a test drives several git calls at once: `status` answers what
  /// the working tree looks like, `log` answers a history, and each stays
  /// readable next to what it is testing.
  final Map<String, String> outputs;

  /// The commands this runner was handed, in the order they arrived.
  final List<List<String>> commands = <List<String>>[];

  @override
  Future<int> run(List<String> command, {String? workingDirectory, Map<String, String>? environment}) async {
    commands.add(command);
    return exitCode;
  }

  @override
  Future<String> capture(List<String> command, {String? workingDirectory}) async {
    commands.add(command);

    for (final MapEntry<String, String> answer in outputs.entries) {
      if (command.contains(answer.key)) return answer.value;
    }

    return output;
  }

  @override
  Future<ProcessOutcome> observe(
    List<String> command, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    commands.add(command);

    for (final MapEntry<String, String> answer in outputs.entries) {
      if (command.contains(answer.key)) {
        return ProcessOutcome(exitCode: exitCode, stdout: answer.value, stderr: '');
      }
    }

    return ProcessOutcome(exitCode: exitCode, stdout: output, stderr: '');
  }

  @override
  ProcessOutcome observeSync(List<String> command, {String? workingDirectory, Map<String, String>? environment}) {
    commands.add(command);

    for (final MapEntry<String, String> answer in outputs.entries) {
      if (command.contains(answer.key)) {
        return ProcessOutcome(exitCode: exitCode, stdout: answer.value, stderr: '');
      }
    }

    return ProcessOutcome(exitCode: exitCode, stdout: output, stderr: '');
  }

  @override
  void detach(List<String> command, {String? workingDirectory}) {
    commands.add(command);
  }
}
