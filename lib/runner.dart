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

import 'package:args/command_runner.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/context_runner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';

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
