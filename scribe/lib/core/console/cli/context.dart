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

import '../framework/app/console_app.dart';
import '../framework/framework.dart';
import 'app.dart';
import 'argument.dart';
import 'command.dart';
import 'exception.dart';
import 'logger.dart';
import 'scope.dart';
import 'usage.dart';

class Context {
  const Context({required this.app, required this.command, required this.path, required this.arguments});

  final Cli app;
  final Command command;
  final List<String> path;
  final Arguments arguments;

  Log get log => Log(command.name);

  String get invocation => <String>[app.name, ...path].join(' ');

  bool get isInteractive => stdin.hasTerminal && stdout.hasTerminal;

  bool get assumesYes => arguments.flag(yesFlag.name);

  bool get isVerbose => arguments.flag(verboseFlag.name);

  Future<T?> show<T>(ConsoleApp app) => runConsole<T>(Scope(cli: this, child: app));

  void render(Widget widget) => renderConsole(Scope(cli: this, child: widget));

  void showUsage() => renderConsole(Usage(app: app, command: command, path: path));

  Never fail(String message, {int exitCode = 1}) => throw CliException(message, exitCode: exitCode);

  Never usageError(String message) => throw CliUsageError(message, path: path);
}

void renderCliUsage(Cli app, {Command? command, List<String> path = const <String>[], Stdout? output}) => renderConsole(
  Usage(app: app, command: command, path: path),
  output: output,
);
