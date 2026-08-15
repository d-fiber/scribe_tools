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

import '../framework/framework.dart';
import '../widgets/text/text.dart';
import 'argument.dart';
import 'command.dart';
import 'context.dart';
import 'exception.dart';
import 'parser.dart';
import 'usage.dart';

const Flag helpFlag = Flag('help', abbr: 'h', help: 'Print this usage information.');

const Flag verboseFlag = Flag('verbose', abbr: 'v', help: 'Print more details while the command runs.');

const Flag yesFlag = Flag('yes', abbr: 'y', help: 'Answer yes to every confirmation.');

typedef Interceptor = Future<void> Function(Context cli);

typedef ErrorDescriber = String? Function(Object error);

class Cli {
  Cli({
    required this.name,
    required this.description,
    this.version,
    List<Command> commands = const <Command>[],
    this.globalFlags = const <Flag>[],
    this.globalOptions = const <Option<Object?>>[],
    this.beforeRun,
    this.describeError,
  }) : commands = <Command>[] {
    commands.forEach(addCommand);
  }

  final String name;
  final String description;
  final String? version;
  final List<Command> commands;
  final List<Flag> globalFlags;
  final List<Option<Object?>> globalOptions;
  final Interceptor? beforeRun;
  final ErrorDescriber? describeError;

  Grammar get globals => Grammar(flags: globalFlags, options: globalOptions);

  List<Command> get visibleCommands => <Command>[
    for (final Command command in commands)
      if (!command.hidden) command,
  ];

  void addCommand(Command command) {
    assert(_free(command), 'Cli already has a command answering to "${command.name}"');
    commands.add(command);
  }

  Command? locate(List<String> path) {
    Command? found;
    List<Command> available = commands;

    for (final String step in path) {
      found = null;
      for (final Command command in available) {
        if (!command.answersTo(step)) continue;
        found = command;
        available = command.commands;
        break;
      }
      if (found == null) return null;
    }
    return found;
  }

  bool _free(Command command) =>
      !commands.any((Command existing) => <String>[command.name, ...command.aliases].any(existing.answersTo));
}

Future<int> run(Cli app, List<String> input) async {
  try {
    final Invocation invocation = input.isEmpty
        ? const Invocation(command: null, path: <String>[], arguments: Arguments(wantsHelp: true))
        : resolveInvocation(app.commands, input, globals: app.globals);

    if (invocation.wantsVersion) {
      renderConsole(Text(app.version ?? 'unknown'));
      return 0;
    }

    final Command? command = invocation.command;
    if (command == null || invocation.wantsHelp) {
      renderCliUsage(app, command: command, path: invocation.path);
      return 0;
    }

    final Context context = Context(app: app, command: command, path: invocation.path, arguments: invocation.arguments);

    await app.beforeRun?.call(context);
    for (final Command step in invocation.chain) {
      for (final Middleware middleware in step.middlewares) {
        await middleware(context);
      }
    }

    await command.run(context);
    return 0;
  } on CliUsageError catch (error) {
    renderConsole(
      Usage(app: app, command: app.locate(error.path), path: error.path, error: error.message),
      output: stderr,
    );
    return error.exitCode;
  } on CliException catch (error) {
    renderConsole(_Failure(error.message), output: stderr);
    return error.exitCode;
  } on Object catch (error) {
    final String? message = app.describeError?.call(error);
    if (message == null) rethrow;

    renderConsole(_Failure(message), output: stderr);
    return 1;
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(message, color: ConsoleTheme.of(context).colors.feedback.error);
}
