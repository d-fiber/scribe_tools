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

import 'package:args/command_runner.dart';
import 'package:sdk/commands/deploy/deploy_command.dart';
import 'package:sdk/commands/backup/backup_command.dart';
import 'package:sdk/commands/dump/dump_command.dart';
import 'package:sdk/commands/gen/gen_command.dart';
import 'package:sdk/commands/install/install_command.dart';
import 'package:sdk/commands/keys/keys_command.dart';
import 'package:sdk/commands/migrations/migrations_command.dart';
import 'package:sdk/commands/test/test_command.dart';
import 'package:sdk/core/exception.dart';
import 'package:sdk/core/logger.dart';

Future<void> main(List<String> arguments) async {
  final CommandRunner<dynamic> runner =
      CommandRunner<dynamic>('sdk', 'The scribe framework CLI. Internal to framework development, never shipped to projects.')
        ..addCommand(InstallCommand())
        ..addCommand(KeysCommand())
        ..addCommand(DeployCommand())
        ..addCommand(BackupCommand())
        ..addCommand(DumpCommand())
        ..addCommand(GenCommand())
        ..addCommand(MigrationsCommand())
        ..addCommand(TestCommand());

  try {
    await runner.run(arguments);
  } on CliException catch (e) {
    stderr.writeln('$ansiRed${e.message}$ansiReset');
    exit(1);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    exit(64);
  }
}
