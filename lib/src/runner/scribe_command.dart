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
import 'package:meta/meta.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/commands/doctor/checkup.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';
import 'package:scribe_tools/src/tools.dart';
import 'package:scribe_tools/src/updates.dart';

/// How a command ended.
///
/// [warning] is a success the user should read: the command did its work and
/// found something worth saying. Only [fail] turns into a non-zero status.
enum ExitStatus {
  /// The command did what it was asked, with nothing to add.
  success,

  /// The command did what it was asked, and found something worth saying.
  warning,

  /// The command could not do what it was asked.
  fail,
}

/// What a command answers when it returns.
class ScribeCommandResult {
  /// Ends the command on [exitStatus].
  const ScribeCommandResult(this.exitStatus);

  /// Ends the command on [ExitStatus.success].
  const ScribeCommandResult.success() : this(ExitStatus.success);

  /// Ends the command on [ExitStatus.warning].
  const ScribeCommandResult.warning() : this(ExitStatus.warning);

  /// Ends the command on [ExitStatus.fail].
  const ScribeCommandResult.fail() : this(ExitStatus.fail);

  /// How the command ended.
  final ExitStatus exitStatus;

  @override
  String toString() => exitStatus.name;
}

/// The base every scribe command extends.
///
/// A subclass writes [runCommand] and, when they are not the default, declares
/// [requiresProject], [requiresCompleteManifest] and [requiredTools]. What
/// those imply has already been checked and refused by the time [runCommand] is
/// reached, so a command never opens with a guard of its own.
abstract class ScribeCommand extends Command<void> {
  /// Builds the parser this command reads its arguments with.
  ScribeCommand();

  /// The command being run, or null outside one.
  static ScribeCommand? get current => globals.context.get<ScribeCommand>();

  /// The parser this command reads its arguments with.
  ///
  /// The one `package:args` builds by default never wraps, so an option whose
  /// help runs to three sentences is printed as a single line and the terminal
  /// breaks it mid-word. This one is told how wide the terminal is.
  @override
  ArgParser get argParser => _argParser;

  final ArgParser _argParser = ArgParser(usageLineLength: globals.stdio.terminalColumns);

  /// Whether this command refuses to run anywhere but the root of a project.
  ///
  /// True unless a subclass says otherwise, since a command that writes into a
  /// project needs one. `create` and `doctor` are the two that say no.
  bool get requiresProject => true;

  /// Whether this command needs `config.yaml` to be valid, and not merely present.
  bool get requiresCompleteManifest => false;

  /// The external tools this command cannot work without.
  ///
  /// They are looked for, and offered for installation, before [runCommand]
  /// runs.
  List<ExternalTool> get requiredTools => const <ExternalTool>[];

  /// Whether this command ends by saying that a newer framework is out.
  ///
  /// True everywhere but the three commands that are about versions
  /// themselves: `doctor` carries the same line in its report, and `upgrade`
  /// and `downgrade` have just moved the checkout, so announcing what they did
  /// would be one line saying what the line above it already said.
  bool get checksVersion => true;

  /// Whether the machine is checked before this command does anything.
  ///
  /// True everywhere but `doctor`, which is that check and is the one command
  /// that has to run on a machine missing something. A group never reaches
  /// this: `package:args` refuses it for the subcommand it is missing first.
  bool get checksMachine => true;

  /// The project this command runs in.
  ///
  /// Throws a [ToolExit] when the current directory is not a project root. A
  /// command declaring [requiresProject] has already been refused by then.
  Project get project => _project ??= Project.current;

  Project? _project;

  /// Opens a context for this command, runs it, and traces how it ended.
  ///
  /// The context carries the command itself, which is what [current] reads.
  ///
  /// The trace says whether the command went through, because it is printed
  /// before the error that stopped it: a bare duration ahead of a refusal reads
  /// as if the work had been done.
  @override
  Future<void> run() {
    final Stopwatch stopwatch = Stopwatch()..start();

    return globals.context.run<void>(
      name: 'command',
      overrides: <Type, Generator>{ScribeCommand: () => this},
      body: () async {
        try {
          final ScribeCommandResult result = await verifyThenRunCommand();
          if (result.exitStatus == ExitStatus.fail) throwToolExit(null);
          globals.logger.printTrace('$invocationName finished in ${stopwatch.elapsedMilliseconds}ms');
        } catch (_) {
          globals.logger.printTrace('$invocationName stopped after ${stopwatch.elapsedMilliseconds}ms');
          rethrow;
        } finally {
          stopwatch.stop();
        }
      },
    );
  }

  /// Runs [validateCommand], then [runCommand], then the version notice.
  ///
  /// Override it to wrap the three. Nothing else sits between the checks and
  /// the work.
  ///
  /// The notice comes last because it is the least of what is on screen: a
  /// command that ran is read from its own output, and this is a line under it.
  @protected
  Future<ScribeCommandResult> verifyThenRunCommand() async {
    await validateCommand();
    final ScribeCommandResult result = await runCommand();

    if (checksVersion) await announceUpdate();

    return result;
  }

  /// Refuses the run when something this command needs is missing.
  ///
  /// Four gates, in this order: the tools every command needs when
  /// [checksMachine], the tools of [requiredTools], the project root when
  /// [requiresProject], and the manifest when [requiresCompleteManifest].
  ///
  /// The first one is `doctor` run under its breath. It says nothing on a
  /// machine that has everything, and prints the whole report on one that does
  /// not, because a missing `deno` is going to stop the run anyway, and it stops it
  /// here before anything has been written.
  ///
  /// Being at the root is not enough on its own: a directory can hold a
  /// `config.yaml` and nothing else, and the entries a project needs are
  /// checked too.
  ///
  /// Throws a [ToolExit] naming what is missing.
  @protected
  Future<void> validateCommand() async {
    if (checksMachine) {
      await ensureToolsAreInstalled(invocationName, assumeYes: ScribeCommandRunner.assumesYes(globalResults));
    }

    await globals.tools.ensure(
      requiredTools,
      install: globalResults?[ScribeGlobalOptions.install] as bool? ?? true,
      assumeYes: globalResults?[ScribeGlobalOptions.yes] as bool? ?? false,
    );

    if (!requiresProject) return;

    _project = Project.current;

    final List<String> missing = project.missingEntries;
    if (missing.isNotEmpty) {
      throwToolExit(
        '${project.directory.path} holds a ${Project.configFileName} but is missing '
        '${missing.join(', ')}.\n'
        'A project needs its three entries: ${Project.configFileName}, lib/ and the derived directory.',
      );
    }

    if (requiresCompleteManifest) project.manifest.ensureComplete();
  }

  /// What this command does, once every check has passed.
  @protected
  Future<ScribeCommandResult> runCommand();

  /// Prints the usage through the logger, so it obeys `-q` like everything else.
  @override
  void printUsage() => globals.logger.printStatus(usage);

  /// Whether flag [name] was passed.
  bool boolArg(String name) => argResults?[name] as bool? ?? false;

  /// The value given to option [name], or null when it was not given.
  String? stringArg(String name) => argResults?[name] as String?;

  /// The value given to option [name].
  ///
  /// Throws a [UsageError] when it was not given.
  String requireStringArg(String name) =>
      stringArg(name) ?? (throw UsageError('Option --$name is required.', command: this.name));

  /// Every value given to the repeatable option [name], empty when it was not given.
  List<String> stringsArg(String name) => (argResults?[name] as List<String>?) ?? const <String>[];

  /// The value given to option [name] read as a whole number, or null when it was not given.
  ///
  /// Throws a [UsageError] when what was given is not a number.
  int? intArg(String name) {
    final String? raw = stringArg(name);
    if (raw == null) return null;

    final int? parsed = int.tryParse(raw);
    if (parsed == null) throwUsageError('--$name expects a whole number, got "$raw".', command: this.name);
    return parsed;
  }

  /// The one argument left once the options are parsed, [label] naming it.
  ///
  /// [explain] says what that argument stands for and is printed under the
  /// refusal, ahead of the usage the runner appends. A caller who got the line
  /// wrong then reads what to write instead of being told to try `--help`.
  ///
  /// A second argument is refused rather than dropped: an unknown word is
  /// almost always a misspelled option, and silently ignoring it would create
  /// something the user did not ask for.
  ///
  /// [alsoWrong] is another thing the line got wrong, already written as a
  /// sentence, and it is said in the same refusal. A user who forgot the
  /// argument and misspelled an option fixes both at once instead of being
  /// refused twice.
  ///
  /// Throws a [UsageError] when there is no argument, and when there are
  /// several.
  String requirePositional(String label, {String? explain, String? alsoWrong}) {
    final List<String> rest = argResults?.rest ?? const <String>[];

    if (rest.isEmpty) {
      throwUsageError(<String>['$invocationName needs a <$label>.', ?alsoWrong, ?explain].join('\n\n'), command: name);
    }

    if (rest.length > 1) {
      final String extra = rest.skip(1).map((String word) => '"$word"').join(', ');
      final String tooMany =
          '$invocationName takes a single <$label>. It read "${rest.first}" as the <$label>, '
          'and has nothing to do with $extra.';
      throwUsageError(<String>[tooMany, ?alsoWrong].join('\n\n'), command: name);
    }

    return rest.first;
  }

  /// This command's usage, without the description a refusal has already said.
  ///
  /// `Command.usage` opens with [description], which repeats the sentence the
  /// refusal above it is made of, two messages where there is one thing to
  /// say. What follows it is what a reader needs and nothing else: the line to
  /// type, the options, and where the global ones are.
  String get usageWithoutDescription => <String>[
    'Usage: $invocation',
    argParser.usage,
    '',
    'Run "${runner?.executableName ?? kToolName} help" to see global options.',
  ].join('\n');

  /// This command as it is typed, parents included: `scribe gen code`.
  String get invocationName {
    final List<String> path = <String>[name];
    for (Command<void>? above = parent; above != null; above = above.parent) {
      path.insert(0, above.name);
    }

    return <String>[runner?.executableName ?? kToolName, ...path].join(' ');
  }
}

/// A command that holds subcommands and does nothing itself.
///
/// Running it prints its usage. It needs no project, since each subcommand
/// decides that for itself.
abstract class ScribeCommandGroup extends ScribeCommand {
  /// Builds a group, which needs no project of its own.
  ScribeCommandGroup();

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    printUsage();
    return const ScribeCommandResult.success();
  }
}
