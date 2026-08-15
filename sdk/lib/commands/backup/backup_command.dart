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

import 'package:args/command_runner.dart';

import '../../core/exception.dart';
import '../../ops/compose.dart';
import '../../ops/env_file.dart';
import '../../ops/project_command.dart';

Future<void> _pgbackrest(List<String> arguments) async {
  if (!EnvFile.exists() || EnvFile.read('PGBACKREST_ARCHIVE_MODE') != 'on') {
    throw CliException(
      "L'archivage n'est pas configuré : remplis integrations.backup dans "
      'config.yaml, régénère le .env, puis redémarre la stack.',
    );
  }

  await Compose.run(
    (await Compose.docker())
      ..exec()
      ..noTty()
      ..service('db')
      ..command(<String>['pgbackrest', ...arguments]),
  );
}

class BackupInitCommand extends ProjectCommand {
  BackupInitCommand() : super(logScope: 'backup');

  @override
  final String name = 'init';

  @override
  final String description = 'Create the pgBackRest stanza in the repository (once per cluster).';

  @override
  Future<void> runCommand() => _pgbackrest(<String>['stanza-create']);
}

class BackupRunCommand extends ProjectCommand {
  BackupRunCommand() : super(logScope: 'backup') {
    argParser.addOption(
      'type',
      allowed: <String>['full', 'diff', 'incr'],
      defaultsTo: 'full',
      help: 'Backup type.',
    );
  }

  @override
  final String name = 'run';

  @override
  final String description = 'Take a backup. Schedule `full` weekly and `diff` daily from the host cron.';

  @override
  Future<void> runCommand() => _pgbackrest(<String>['--type=${argResults!['type']}', 'backup']);
}

class BackupCheckCommand extends ProjectCommand {
  BackupCheckCommand() : super(logScope: 'backup');

  @override
  final String name = 'check';

  @override
  final String description = 'Verify that archiving and the repository are healthy.';

  @override
  Future<void> runCommand() => _pgbackrest(<String>['check']);
}

class BackupInfoCommand extends ProjectCommand {
  BackupInfoCommand() : super(logScope: 'backup');

  @override
  final String name = 'info';

  @override
  final String description = 'List the backups held in the repository and the recoverable window.';

  @override
  Future<void> runCommand() => _pgbackrest(<String>['info']);
}

class BackupCommand extends Command<dynamic> {
  BackupCommand() {
    addSubcommand(BackupInitCommand());
    addSubcommand(BackupRunCommand());
    addSubcommand(BackupCheckCommand());
    addSubcommand(BackupInfoCommand());
  }

  @override
  final String name = 'backup';

  @override
  final String description = 'Continuous Postgres archiving to S3 (pgBackRest).';
}
