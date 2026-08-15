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
import 'argument.dart';
import 'context.dart';
import 'exception.dart';

typedef Middleware = Future<void> Function(Context cli);

abstract class Command {
  const Command();

  String get name;

  String get description;

  List<String> get aliases => const <String>[];

  List<Flag> get flags => const <Flag>[];

  List<Option<Object?>> get options => const <Option<Object?>>[];

  List<Positional> get positionals => const <Positional>[];

  List<Command> get commands => const <Command>[];

  List<Middleware> get middlewares => const <Middleware>[];

  String? get usage => null;

  bool get hidden => false;

  bool get requiresTerminal => false;

  bool get isGroup => commands.isNotEmpty;

  List<Command> get visibleCommands => <Command>[
    for (final Command command in commands)
      if (!command.hidden) command,
  ];

  bool answersTo(String token) => token == name || aliases.contains(token);

  Future<void> run(Context cli);
}

abstract class GroupCommand extends Command {
  const GroupCommand();

  @override
  Future<void> run(Context cli) async => cli.showUsage();
}

abstract class ScreenCommand extends Command {
  const ScreenCommand();

  ConsoleApp build(Context cli);

  @override
  bool get requiresTerminal => true;

  @override
  Future<void> run(Context cli) {
    if (!stdin.hasTerminal || !stdout.hasTerminal) {
      throw CliException(
        '`${cli.invocation}` needs an interactive terminal. '
        'Run it from a shell, or pass the values as options in a script.',
        exitCode: 64,
      );
    }

    return cli.show<void>(build(cli));
  }
}
