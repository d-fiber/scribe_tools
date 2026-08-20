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

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/terminal.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';

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
        usageLineLength: globals.stdio.terminalColumns,
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

  /// The version `--version` prints.
  final String toolVersion;

  /// Whether [results] carry `--yes`, so nothing has to be asked.
  static bool assumesYes(ArgResults? results) => results?[ScribeGlobalOptions.yes] as bool? ?? false;

  /// The usage of the command called [name], null when no command carries it.
  ///
  /// [name] is a leaf name and the search goes through subcommands, so `code`
  /// finds `scribe gen code`. It is what turns a [UsageError] into the same
  /// message `package:args` prints on its own refusals: what went wrong, then
  /// the options the command accepts.
  String? usageOf(String? name) {
    if (name == null) return null;

    final Command<void>? found = _find(name, commands);
    if (found is ScribeCommand) return found.usageWithoutDescription;

    return found?.usage;
  }

  static Command<void>? _find(String name, Map<String, Command<void>> among) {
    for (final Command<void> command in among.values) {
      if (command.name == name) return command;

      if (_find(name, command.subcommands) case final Command<void> nested) return nested;
    }

    return null;
  }

  /// Rebuilds the output from the global options, then dispatches to the command.
  ///
  /// The context opened here is what everything underneath reads, so `-v`, `-q`
  /// and `--color` reach code that never asked what they were set to.
  ///
  /// Prompting is only enabled once this point is passed: nothing may ask the
  /// user a question before `--yes` has been parsed.
  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    final bool verbose = topLevelResults[ScribeGlobalOptions.verbose] as bool;
    final bool quiet = topLevelResults[ScribeGlobalOptions.quiet] as bool;
    final bool? color = topLevelResults[ScribeGlobalOptions.color] as bool?;
    final Logger? injected = globals.context.get<Logger>();

    return globals.context.run<void>(
      name: 'global',
      overrides: <Type, Generator>{
        OutputPreferences: () => OutputPreferences(
          stdio: globals.stdio,
          showColor: color ?? globals.terminal.supportsColor,
        ),
        Terminal: () => AnsiTerminal(stdio: globals.stdio, platform: globals.platform),
        Logger: () => _loggerFor(verbose: verbose, quiet: quiet, injected: injected),
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

  /// The logger the run prints through, [injected] taking the place of stdout.
  ///
  /// A test registers its own logger in the context and still gets the `-v` and
  /// `-q` wrappers around it, so what the user would have read is what the test
  /// reads.
  Logger _loggerFor({required bool verbose, required bool quiet, Logger? injected}) {
    final Logger stdout =
        injected ??
        StdoutLogger(
          terminal: globals.terminal,
          stdio: globals.stdio,
          outputPreferences: globals.outputPreferences,
        );

    if (verbose) {
      final VerboseLogger logger = VerboseLogger(stdout);
      logger.printTrace('verbose logging on; the bracket that opens each line is the time since the line above');
      return logger;
    }

    if (quiet) return QuietLogger(stdout);
    return stdout;
  }
}

/// A [DelegatingLogger] that drops everything but errors and warnings.
///
/// Progress is silent rather than absent, so a caller still gets a [Status] to
/// end and nothing above has to know it is being quiet. This is what `-q`
/// builds.
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
