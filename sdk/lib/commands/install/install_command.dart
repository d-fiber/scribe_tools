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

import '../../core/commands/docker.dart';
import '../../core/process.dart';
import '../../ops/compose.dart';
import '../../ops/config.dart';
import '../../ops/env_file.dart';
import '../../ops/project_command.dart';
import 'install_instructions.dart';
import 'linux/linux_networking.dart';
import 'linux/linux_provisioning.dart';
import 'stack/database_provisioning.dart';
import 'stack/local_dependencies.dart';
import 'stack/reinstall.dart';
import 'stack/service_health.dart';
import 'support.dart';

class InstallCommand extends ProjectCommand
    with
        LocalDependencies,
        LinuxProvisioning,
        LinuxNetworking,
        Reinstall,
        ServiceHealth,
        DatabaseProvisioning,
        InstallInstructions {
  @override
  final String name = 'install';

  @override
  final String description = 'Install server dependencies and start the full stack.';

  InstallCommand() : super(logScope: 'install', requiresInstall: false) {
    argParser.addFlag(
      'local',
      help:
          'Local/dev setup: skip Linux system provisioning (apt, ufw, iptables, '
          'sysctl) and just bring up the stack for testing. Implied automatically '
          'when not running on Linux.',
      negatable: false,
    );
  }

  @override
  Future<void> runCommand() async {
    final bool requestedLocal = argResults!.flag('local');
    final bool isLocal = requestedLocal || !Platform.isLinux;

    if (isLocal) {
      log.info(
        requestedLocal
            ? 'Local/dev mode skipping Linux system provisioning (apt, ufw, iptables, sysctl).'
            : 'Not running on Linux switching to local/dev mode (skipping apt, ufw, iptables, sysctl).',
      );
    }

    final Config cfg = config;

    final bool dockerOk = await commandExists('docker');
    final bool hasEnv = EnvFile.exists();
    final ProcessResult? psResult = dockerOk
        ? await Compose.capture(
            (await Compose.docker())
              ..ps()
              ..quiet(),
          )
        : null;
    final bool running = dockerOk && ((psResult?.stdout as String? ?? '').trim().isNotEmpty);

    if (hasEnv || running) {
      final bool reinstall = await confirmReinstall(hasEnv: hasEnv, running: running);
      if (!reinstall) {
        log.info('Aborted.');
        return;
      }
      await teardown(isLocal: isLocal);
      print('');
    }

    if (isLocal) {
      await checkLocalDependencies();
    } else {
      await provisionLinuxSystem(dockerOk);
    }

    final ProcessResult composeVersion = await captureCommand(
      Docker()
        ..compose()
        ..version(),
    );
    if (composeVersion.exitCode != 0) {
      log.error('docker compose (v2) not found. Please install docker-compose-plugin.');
    }

    if (!EnvFile.exists()) {
      log.info('Generating secrets...');
      await EnvFile.generate(cfg);
      log.info('.env generated.');
    } else {
      log.info('.env already exists skipping secret generation.');
    }

    if (!isLocal) {
      await openLinuxFirewallAndVpnNetworking();
    }

    await ensureOpensearchDir(isLocal: isLocal);

    log.info('Starting containers...');
    await Compose.run(
      (await Compose.docker())
        ..up()
        ..detach()
        ..removeOrphans(),
    );

    await waitForServices(cfg);
    await provision();

    printInstructions(cfg);
  }
}
