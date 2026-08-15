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

import 'package:interact/interact.dart';

import '../../../core/commands/base/rm.dart';
import '../../../core/logger.dart';
import '../../../core/paths/infra_files.dart';
import '../../../core/process.dart';
import '../../../ops/compose.dart';
import '../../../ops/env_file.dart';
import '../../../ops/project_command.dart';
import '../support.dart';

mixin Reinstall on ProjectCommand {
  Future<void> _rmrf(Directory directory) async {
    await streamPrivilegedCommand(
      Rm()
        ..recursive()
        ..force()
        ..path(directory.path),
    );
  }

  Future<bool> confirmReinstall({required bool hasEnv, required bool running}) async {
    print('');
    print('$ansiYellow╔══════════════════════════════════════════════════╗$ansiReset');
    print('$ansiYellow║         Existing installation detected           ║$ansiReset');
    print('$ansiYellow╚══════════════════════════════════════════════════╝$ansiReset');
    print('');
    if (running) log.info('Containers are currently running.');
    if (hasEnv) log.info('.env file already exists.');
    print('');
    print('  ${ansiRed}Warning:$ansiReset reinstalling will permanently delete all data');
    print('  (database, volumes, secrets).');
    print('');

    final bool answer = Confirm(prompt: '  Reinstall from scratch?', defaultValue: false).interact();
    print('');
    return answer;
  }

  Future<void> teardown({required bool isLocal}) async {
    log.info('Stopping containers and removing volumes...');
    await Compose.capture(
      (await Compose.docker())
        ..down()
        ..volumes()
        ..removeOrphans(),
    );
    log.info('Deleting database data...');
    await _rmrf(InfraFiles.tree.scribe.postgres.directory);
    log.info('Deleting OpenSearch data...');
    await _rmrf(InfraFiles.tree.scribe.opensearch.directory);
    await ensureOpensearchDir(isLocal: isLocal);
    if (EnvFile.exists()) {
      EnvFile.delete();
      log.info('.env deleted new secrets will be generated.');
    }
    log.info('Teardown complete. Starting fresh installation...');
  }
}
