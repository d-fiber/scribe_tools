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

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';
import 'package:scribe/src/runner/scribe_command_runner.dart';
import 'package:scribe/src/tools.dart';

enum ExitStatus { success, warning, fail }

class ScribeCommandResult {
  const ScribeCommandResult(this.exitStatus);

  const ScribeCommandResult.success() : this(ExitStatus.success);

  const ScribeCommandResult.warning() : this(ExitStatus.warning);

  const ScribeCommandResult.fail() : this(ExitStatus.fail);

  final ExitStatus exitStatus;

  @override
  String toString() => exitStatus.name;
}

abstract class ScribeCommand extends Command<void> {
  ScribeCommand();

  static ScribeCommand? get current => globals.context.get<ScribeCommand>();

  bool get requiresProject => true;

  bool get requiresCompleteManifest => false;

  List<ExternalTool> get requiredTools => const <ExternalTool>[];

  Project get project => _project ??= Project.current;

  Project? _project;

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
        } finally {
          stopwatch.stop();
          globals.logger.printTrace('$name took ${stopwatch.elapsedMilliseconds}ms');
        }
      },
    );
  }

  @protected
  Future<ScribeCommandResult> verifyThenRunCommand() async {
    await validateCommand();
    return runCommand();
  }

  @protected
  Future<void> validateCommand() async {
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

  @protected
  Future<ScribeCommandResult> runCommand();

  @override
  void printUsage() => globals.logger.printStatus(usage);

  bool boolArg(String name) => argResults?[name] as bool? ?? false;

  String? stringArg(String name) => argResults?[name] as String?;

  String requireStringArg(String name) =>
      stringArg(name) ?? (throw UsageError('Option --$name is required.', command: this.name));

  List<String> stringsArg(String name) => (argResults?[name] as List<String>?) ?? const <String>[];

  int? intArg(String name) {
    final String? raw = stringArg(name);
    if (raw == null) return null;

    final int? parsed = int.tryParse(raw);
    if (parsed == null) throwUsageError('--$name expects a whole number, got "$raw".', command: this.name);
    return parsed;
  }

  String requirePositional(String label) {
    final List<String> rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) throwUsageError('<$label> is required.', command: name);
    return rest.first;
  }
}

abstract class ScribeCommandGroup extends ScribeCommand {
  ScribeCommandGroup();

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    printUsage();
    return const ScribeCommandResult.success();
  }
}
