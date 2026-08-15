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
import 'package:interact/interact.dart';

import '../../ops/compose.dart';
import '../../ops/project_command.dart';

class _MigrationScope {
  const _MigrationScope({required this.label, required this.containerDir, required this.table});

  final String label;
  final String containerDir;
  final String table;
}

const _MigrationScope _defaultScope = _MigrationScope(
  label: 'scribe/host/caleb/db/migrations',
  containerDir: '/db/migrations/default',
  table: 'schema_migrations',
);

// Kernel-only : pas de scope lib/db/migrations ici (kernel-cli n'a pas
// connaissance de lib/, voir tool/generate_paths.dart). Le service
// db-migrate (scripts/db/run-migrations.sh) applique de toute façon les deux
// scopes en interne quel que soit le CLI qui le déclenche ; ceci n'affecte
// que l'affichage du statut côté Dart.
List<_MigrationScope> _activeScopes() => const <_MigrationScope>[_defaultScope];

Future<void> _printStatus(_MigrationScope scope) async {
  print('\n▶ ${scope.label}');
  await Compose.run(
    (await Compose.docker())
      ..run()
      ..rm()
      ..noDeps()
      ..entrypoint('dbmate')
      ..service('db-migrate')
      ..command(<String>['--migrations-dir', scope.containerDir, '--migrations-table', scope.table, 'status']),
  );
}

class MigrationsCommand extends Command<dynamic> {
  MigrationsCommand() {
    addSubcommand(MigrationsUpCommand());
    addSubcommand(MigrationsStatusCommand());
  }

  @override
  final String name = 'migrations';

  @override
  final String description = 'Apply and inspect Postgres schema migrations (dbmate).';
}

class MigrationsUpCommand extends ProjectCommand {
  MigrationsUpCommand() : super(logScope: 'migrations up') {
    argParser.addFlag(
      'yes',
      abbr: 'y',
      help: 'Skip the confirmation prompt (non-interactive/CI use).',
      negatable: false,
    );
  }

  @override
  final String name = 'up';

  @override
  final String description = 'Apply every pending migration under scribe/host/caleb/db/migrations.';

  @override
  Future<void> runCommand() async {
    for (final _MigrationScope scope in _activeScopes()) {
      await _printStatus(scope);
    }

    if (!argResults!.flag('yes')) {
      print('');
      final bool answer = Confirm(prompt: '  Apply the pending migrations above?', defaultValue: false).interact();
      print('');
      if (!answer) {
        log.info('Aborted no migrations applied.');
        return;
      }
    }

    await Compose.run(
      (await Compose.docker())
        ..run()
        ..rm()
        ..noDeps()
        ..service('db-migrate'),
    );
    log.info('Migrations applied.');
  }
}

class MigrationsStatusCommand extends ProjectCommand {
  MigrationsStatusCommand() : super(logScope: 'migrations status');

  @override
  final String name = 'status';

  @override
  final String description = 'Show which migrations are applied vs pending.';

  @override
  Future<void> runCommand() async {
    for (final _MigrationScope scope in _activeScopes()) {
      await _printStatus(scope);
    }
  }
}
