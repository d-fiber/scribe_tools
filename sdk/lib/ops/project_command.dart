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

import '../core/logger.dart';
import 'config.dart';
import 'env_file.dart';

abstract class ProjectCommand extends Command {
  ProjectCommand({required String logScope, this.requiresInstall = true})
    : log = Log(logScope);

  final Log log;
  final bool requiresInstall;

  late final Config config;

  @override
  Future<void> run() async {
    config = Config.read();
    config.validate();

    if (requiresInstall) _checkInstallConsistency();

    await runCommand();
  }

  void _checkInstallConsistency() {
    if (!EnvFile.exists()) {
      log.error('No .env found for this config.yaml run `install` first.');
    }

    final String stored = EnvFile.read('CONFIG_FINGERPRINT');
    if (stored.isEmpty) return;

    if (stored != config.fingerprint) {
      log.error(
        "config.yaml's NAME/URL no longer match what this stack was installed with "
        're-run `install` to apply the change, or revert config.yaml.',
      );
    }
  }

  Future<void> runCommand();
}
