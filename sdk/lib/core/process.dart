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

import 'dart:io';

import 'exception.dart';
import 'logger.dart';

Future<void> sh(
  String executable,
  List<String> args, {
  String? cwd,
  Map<String, String>? env,
}) async {
  final Process process = await Process.start(
    executable,
    args,
    workingDirectory: cwd,
    environment: env,
    mode: ProcessStartMode.inheritStdio,
  );
  final int code = await process.exitCode;
  if (code != 0) {
    throw CliException(
      '${[executable, ...args].join(' ')} exited with code $code',
    );
  }
}

Future<ProcessResult> capture(
  String executable,
  List<String> args, {
  String? cwd,
  Map<String, String>? env,
}) {
  return Process.run(executable, args, workingDirectory: cwd, environment: env);
}

Future<void> shToFile(
  String executable,
  List<String> args,
  File dest, {
  String? cwd,
  Map<String, String>? env,
}) async {
  final Process process = await Process.start(
    executable,
    args,
    workingDirectory: cwd,
    environment: env,
  );
  final Future<void> stderrDone = process.stderr.drain<void>();
  await process.stdout.pipe(dest.openWrite());
  await stderrDone;
  final int code = await process.exitCode;
  if (code != 0) {
    throw CliException(
      '${[executable, ...args].join(' ')} exited with code $code',
    );
  }
}

Future<bool> commandExists(String name) async {
  final String locator = Platform.isWindows ? 'where' : 'which';
  final ProcessResult result = await capture(locator, [name]);
  return result.exitCode == 0;
}

class Invocation {
  Invocation(this.executable, this.args);

  final String executable;
  final List<String> args;

  List<String> get argv => [executable, ...args];
}

Invocation privileged(String executable, List<String> args) {
  if (Platform.isLinux) return Invocation('sudo', [executable, ...args]);
  return Invocation(executable, args);
}

abstract class ShellCommand {
  String get executable;
  List<String> get args;
}

Future<void> streamCommand(
  ShellCommand command, {
  String? cwd,
  Map<String, String>? env,
}) {
  return sh(command.executable, command.args, cwd: cwd, env: env);
}

Future<ProcessResult> captureCommand(
  ShellCommand command, {
  String? cwd,
  Map<String, String>? env,
}) {
  return capture(command.executable, command.args, cwd: cwd, env: env);
}

Future<void> streamPrivilegedCommand(
  ShellCommand command, {
  String? cwd,
  Map<String, String>? env,
}) {
  final Invocation invocation = privileged(command.executable, command.args);
  return sh(invocation.executable, invocation.args, cwd: cwd, env: env);
}

Future<ProcessResult> capturePrivilegedCommand(
  ShellCommand command, {
  String? cwd,
  Map<String, String>? env,
}) {
  final Invocation invocation = privileged(command.executable, command.args);
  return capture(invocation.executable, invocation.args, cwd: cwd, env: env);
}

Future<void> streamCommandToFile(
  ShellCommand command,
  File dest, {
  String? cwd,
  Map<String, String>? env,
}) => shToFile(command.executable, command.args, dest, cwd: cwd, env: env);

Future<void> streamPrivilegedCommandToFile(
  ShellCommand command,
  File dest, {
  String? cwd,
  Map<String, String>? env,
}) {
  final Invocation invocation = privileged(command.executable, command.args);
  return shToFile(
    invocation.executable,
    invocation.args,
    dest,
    cwd: cwd,
    env: env,
  );
}

List<String> commandArgv(ShellCommand command, {bool asPrivileged = false}) {
  if (asPrivileged) return privileged(command.executable, command.args).argv;
  return [command.executable, ...command.args];
}

String commandLine(ShellCommand command) =>
    [command.executable, ...command.args].join(' ');

Future<void> waitUntil(
  Log log,
  String label,
  List<String> cmd, {
  int interval = 2,
  int timeout = 180,
}) async {
  int waited = 0;
  while (true) {
    final ProcessResult result = await capture(cmd.first, cmd.sublist(1));
    if (result.exitCode == 0) return;
    if (waited >= timeout) {
      log.warn('$label not ready after ${timeout}s check logs.');
      return;
    }
    await Future.delayed(Duration(seconds: interval));
    waited += interval;
  }
}
