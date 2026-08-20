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
  const ProcessRunner();

  /// Runs [command], letting it write to this process's streams, and returns its status.
  Future<int> run(List<String> command, {String? workingDirectory});

  /// Runs [command] and returns what it wrote on standard output.
  ///
  /// Standard error is dropped, and the status is not looked at: a command that
  /// failed comes back as an empty string.
  Future<String> capture(List<String> command, {String? workingDirectory});

  /// Starts [command] and forgets it, without waiting for it to end.
  ///
  /// The child outlives this process and writes nowhere it could be seen. It is
  /// how the version check reaches the network without the command the user
  /// typed ever waiting on it.
  void detach(List<String> command, {String? workingDirectory});
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
  Future<int> run(List<String> command, {String? workingDirectory}) async {
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
  void detach(List<String> command, {String? workingDirectory}) {
    commands.add(command);
  }
}
