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

import 'package:scribe/commands/config/config_command.dart';
import 'package:scribe/commands/extensions/extensions_command.dart';
import 'package:scribe/commands/gen/gen_command.dart';
import 'package:scribe/commands/init/init_command.dart';
import 'package:scribe/commands/public/public.dart';
import 'package:scribe/commands/test/test_command.dart';
import 'package:scribe/core/console/console.dart';
import 'package:fiber_shell/fiber_shell.dart';

final Cli cli =
    Cli(
        name: 'scribedb',
        description: 'Everything you need to build on this stack, in one command.',
        version: '1.0.0',
        globalFlags: const <Flag>[yesFlag, verboseFlag],
        describeError: _describeShellFailure,
      )
      ..addCommand(const InitCommand())
      ..addCommand(const ConfigCommand())
      ..addCommand(const GenCommand())
      ..addCommand(const ExtensionsCommand())
      ..addCommand(const PublicCommand())
      ..addCommand(const TestCommand())
      ..addCommand(const CompletionCommand());


String? _describeShellFailure(Object error) => error is ShellException ? error.message : null;

Future<void> main(List<String> arguments) async {
  final int code = await run(cli, arguments);
  if (code != 0) exit(code);
}
