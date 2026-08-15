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

import '../../../core/commands/base/bash.dart';
import '../../../core/commands/base/curl.dart';
import '../../../core/commands/git.dart';
import '../../../core/commands/linux/apt_get.dart';
import '../../../core/commands/linux/usermod.dart';
import '../../../core/paths/infra_files.dart';
import '../../../core/process.dart';
import '../../../ops/project_command.dart';
import '../support.dart';

mixin LinuxProvisioning on ProjectCommand {
  Bash _pipedInstallScript(String url) {
    final Curl fetch = Curl()
      ..failFast()
      ..silent()
      ..showError()
      ..location()
      ..url(url);
    return Bash()
      ..c()
      ..script('${commandLine(fetch)} | sudo -E bash -');
  }

  Future<void> provisionLinuxSystem(bool dockerOk) async {
    log.info('Updating system packages...');
    await runAptGet(
      log,
      AptGet()
        ..update()
        ..yes(),
    );
    await runAptGet(
      log,
      AptGet()
        ..upgrade()
        ..yes(),
    );

    log.info('Installing dependencies...');
    await runAptGet(
      log,
      AptGet()
        ..install()
        ..yes()
        ..package('ca-certificates')
        ..package('curl')
        ..package('gnupg')
        ..package('openssl')
        ..package('xxd')
        ..package('git')
        ..package('ufw')
        ..package('jq')
        ..package('python3-bcrypt'),
    );

    if (!await commandExists('node')) {
      log.info('Installing Node.js 22...');
      await streamCommand(
        _pipedInstallScript('https://deb.nodesource.com/setup_22.x'),
      );
      await runAptGet(
        log,
        AptGet()
          ..install()
          ..yes()
          ..package('nodejs'),
      );
    } else {
      await logToolVersion(log, 'Node.js', 'node');
    }

    if (!dockerOk) {
      log.info('Installing Docker...');
      await streamCommand(_pipedInstallScript('https://get.docker.com'));
      await capturePrivilegedCommand(
        Usermod()
          ..appendGroups()
          ..group('docker')
          ..user(Platform.environment['USER'] ?? 'root'),
      );
    } else {
      await logToolVersion(log, 'Docker', 'docker');
    }

    final ProcessResult gitCheck = await captureCommand(
      Git()
        ..repo(InfraFiles.root.path)
        ..revParse()
        ..isInsideWorkTree(),
    );
    if (gitCheck.exitCode == 0) {
      log.info('Pulling latest changes...');
      await captureCommand(
        Git()
          ..repo(InfraFiles.root.path)
          ..stash(),
      );
      await streamCommand(
        Git()
          ..repo(InfraFiles.root.path)
          ..pull()
          ..rebase(),
      );
    }
  }
}
