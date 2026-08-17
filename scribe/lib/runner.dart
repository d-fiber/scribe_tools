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
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/context_runner.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/runner/scribe_command_runner.dart';

/// The status a command called the wrong way leaves with, as `sysexits.h` names it.
const int kExitCodeUsage = 64;

/// The status an error nobody expected leaves with, as `sysexits.h` names it.
const int kExitCodeCrash = 70;

/// Runs [args] against the commands [commands] builds, and returns the exit status.
///
/// [commands] is a callback and not a list because a command is built inside
/// the context, where the dependencies of `globals` already answer.
///
/// This is where the process learns how it ends, and the only place that knows:
/// a [ToolExit] carries its own status, a command called wrong answers
/// [kExitCodeUsage], anything else answers [kExitCodeCrash], and a run that
/// merely printed an error answers 1. The stack trace is only shown when the
/// run is verbose.
///
/// [overrides] replaces entries of the context, which is how a test runs a
/// command against a memory file system and a buffer logger.
Future<int> run(
  List<String> args,
  List<ScribeCommand> Function() commands, {
  required String toolVersion,
  Map<Type, Generator>? overrides,
}) async {
  return runInContext<int>(() async {
    final ScribeCommandRunner runner = ScribeCommandRunner(toolVersion: toolVersion);
    commands().forEach(runner.addCommand);

    try {
      await runner.run(args);
      return globals.logger.hadErrorOutput ? 1 : 0;
    } on ToolExit catch (error) {
      final String? message = error.message;
      if (message != null && message.isNotEmpty) globals.logger.printError(message);
      return error.exitCode;
    } on UsageError catch (error) {
      globals.logger.printError(error.message);
      if (runner.usageOf(error.command) case final String usage) {
        globals.logger.printStatus('');
        globals.logger.printStatus(usage);
      }
      return kExitCodeUsage;
    } on UsageException catch (error) {
      globals.logger.printError(error.message);
      globals.logger.printStatus('');
      globals.logger.printStatus(error.usage);
      return kExitCodeUsage;
    } catch (error, stackTrace) {
      globals.logger.printError('$error', stackTrace: globals.logger.isVerbose ? stackTrace : null);
      return kExitCodeCrash;
    }
  }, overrides: overrides);
}
