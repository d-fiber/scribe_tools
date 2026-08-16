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

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;

/// The names of the options every command accepts, wherever it sits.
///
/// They are read from `globalResults`, not from a command's own parser, so a
/// subcommand nested two levels down sees the same values as the top one.
class ScribeGlobalOptions {
  static const String verbose = 'verbose';
  static const String quiet = 'quiet';
  static const String color = 'color';
  static const String yes = 'yes';
  static const String install = 'install';
  static const String version = 'version';
}

/// The runner `package:args` dispatches through.
///
/// It reads the global options before any command runs and rebuilds the output
/// preferences, the terminal and the logger from them, so `-v`, `-q` and
/// `--color` are honoured by everything underneath without a command ever
/// asking what they were set to.
class ScribeCommandRunner extends CommandRunner<void> {
  ScribeCommandRunner({required this.toolVersion})
    : super(
        'scribe',
        'Everything a project built on scribe needs, in one command.\n'
            '\n'
            'Common commands:\n'
            '\n'
            '  scribe create <name>\n'
            '    Scaffold a project in ./<name>.\n'
            '\n'
            '  scribe gen code\n'
            '    Rewrite everything the project derives from config.yaml and its SQL.',
      ) {
    argParser
      ..addFlag(
        ScribeGlobalOptions.verbose,
        abbr: 'v',
        negatable: false,
        help: 'Noisy logging, including every command executed.',
      )
      ..addFlag(
        ScribeGlobalOptions.quiet,
        abbr: 'q',
        negatable: false,
        help: 'Only print errors.',
      )
      ..addFlag(
        ScribeGlobalOptions.color,
        help: 'Colour the output. Off when the terminal does not support it.',
        defaultsTo: null,
      )
      ..addFlag(
        ScribeGlobalOptions.yes,
        abbr: 'y',
        negatable: false,
        help: 'Answer yes to every question, for scripts.',
      )
      ..addFlag(
        ScribeGlobalOptions.install,
        help: 'Install the tools a command needs when they are missing.',
        defaultsTo: true,
      )
      ..addFlag(
        ScribeGlobalOptions.version,
        negatable: false,
        help: 'Print the version of this tool.',
      );
  }

  final String toolVersion;

  static bool assumesYes(ArgResults? results) => results?[ScribeGlobalOptions.yes] as bool? ?? false;

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    final bool verbose = topLevelResults[ScribeGlobalOptions.verbose] as bool;
    final bool quiet = topLevelResults[ScribeGlobalOptions.quiet] as bool;
    final bool? color = topLevelResults[ScribeGlobalOptions.color] as bool?;

    return globals.context.run<void>(
      name: 'global',
      overrides: <Type, Generator>{
        OutputPreferences: () => OutputPreferences(
          stdio: globals.stdio,
          showColor: color ?? globals.terminal.supportsColor,
        ),
        Terminal: () => AnsiTerminal(stdio: globals.stdio, platform: globals.platform),
        Logger: () => _loggerFor(verbose: verbose, quiet: quiet),
      },
      body: () async {
        if (topLevelResults[ScribeGlobalOptions.version] as bool) {
          globals.logger.printStatus('scribe $toolVersion');
          return;
        }

        globals.terminal.usesTerminalUi = true;
        await super.runCommand(topLevelResults);
      },
    );
  }

  Logger _loggerFor({required bool verbose, required bool quiet}) {
    final Logger stdout = StdoutLogger(
      terminal: globals.terminal,
      stdio: globals.stdio,
      outputPreferences: globals.outputPreferences,
    );

    if (verbose) return VerboseLogger(stdout);
    if (quiet) return QuietLogger(stdout);
    return stdout;
  }
}

class QuietLogger extends DelegatingLogger {
  QuietLogger(super.delegate);

  @override
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true}) {}

  @override
  void printTrace(String message) {}

  @override
  Status startProgress(String message, {Duration? timeout}) => SilentStatus(stopwatch: Stopwatch())..start();

  @override
  Status startSpinner({VoidCallback? onFinish}) => SilentStatus(stopwatch: Stopwatch(), onFinish: onFinish)..start();
}
