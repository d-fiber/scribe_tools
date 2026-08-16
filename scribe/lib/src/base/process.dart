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

abstract class ProcessRunner {
  const ProcessRunner();

  Future<int> run(List<String> command, {String? workingDirectory});

  Future<String> capture(List<String> command, {String? workingDirectory});
}

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

class RecordingProcessRunner extends ProcessRunner {
  RecordingProcessRunner({this.exitCode = 0, this.output = ''});

  final int exitCode;
  final String output;

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
