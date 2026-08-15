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

import '../../core/commands/base/install.dart';
import '../../core/commands/docker_compose.dart';
import '../../core/commands/psql/psql.dart';
import '../../core/commands/psql/sql.dart';
import '../../core/logger.dart';
import '../../core/paths/infra_files.dart';
import '../../core/process.dart';
import '../../ops/compose.dart';

Future<void> logToolVersion(Log log, String label, String executable) async {
  final ProcessResult result = await capture(executable, ['--version']);
  final String version = (result.stdout as String).trim();
  log.info('$label already installed: $version');
}

Future<DockerCompose> psqlCompose(Sql statement) async {
  final Psql psql = Psql()
    ..user('postgres')
    ..command(statement.render());
  return (await Compose.docker())
    ..exec()
    ..noTty()
    ..service('db')
    ..command(commandArgv(psql));
}

Future<void> ensureOpensearchDir({required bool isLocal}) async {
  final Directory directory = InfraFiles.tree.scribe.opensearch.directory;
  if (isLocal) {
    await directory.create(recursive: true);
    return;
  }
  await streamPrivilegedCommand(
    Install()
      ..directory()
      ..owner('1000')
      ..group('1000')
      ..path(directory.path),
  );
}
