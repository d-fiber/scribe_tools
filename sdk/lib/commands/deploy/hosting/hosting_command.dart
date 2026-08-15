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

import 'package:path/path.dart' as p;

import '../../../core/commands/base/chown.dart';
import '../../../core/commands/base/rm.dart';
import '../../../core/commands/caddy.dart';
import '../../../core/commands/npm.dart';
import '../../../core/paths/infra_files.dart';
import '../../../core/process.dart';
import '../../../ops/compose.dart';
import '../../../ops/project_command.dart';
import '../support.dart';
import 'sites.dart';

class DeployHostingCommand extends ProjectCommand {
  DeployHostingCommand() : super(logScope: 'hosting');

  @override
  final String name = 'hosting';

  @override
  final String description = 'Build all hosted sites and reload Caddy.';

  Future<void> _rmrf(String path) => streamPrivilegedCommand(
    Rm()
      ..recursive()
      ..force()
      ..path(path),
  );

  @override
  Future<void> runCommand() async {
    await pullLatestChanges(log, autostash: true);

    final String user = Platform.environment['USER'] ?? 'ubuntu';
    final Directory hostingDir = InfraFiles.tree.scribe.hosting.directory;
    final List<Site> sites = hostedSites();

    log.info('Installing workspace dependencies...');
    await _rmrf(InfraFiles.tree.scribe.hosting.nodeModules.directory.path);
    for (final Site site in sites) {
      await _rmrf(p.join(site.directory.path, 'node_modules'));
    }
    await streamCommand(
      Npm()
        ..ci()
        ..engineStrictFalse(),
      cwd: hostingDir.path,
    );

    for (final Site site in sites) {
      log.info('[${site.name}] Fixing permissions...');
      for (final Directory dist in site.distDirectories) {
        if (dist.existsSync()) {
          await streamPrivilegedCommand(
            Chown()
              ..recursive()
              ..owner('$user:')
              ..path(dist.path),
          );
        }
      }
      log.info('[${site.name}] Building...');
      for (final String script in site.buildScripts) {
        await streamCommand(
          Npm()
            ..run()
            ..script(script),
          cwd: site.directory.path,
        );
      }
      log.info('[${site.name}] Done.');
    }

    log.info('Restarting Caddy (picks up new mounts)...');
    await Compose.run(
      (await Compose.docker())
        ..up()
        ..detach()
        ..noDeps()
        ..service('caddy'),
    );

    log.info('Reloading Caddy config...');
    await Compose.run(
      (await Compose.docker())
        ..exec()
        ..noTty()
        ..service('caddy')
        ..command(
          commandArgv(
            Caddy()
              ..reload()
              ..configFile('/etc/caddy/Caddyfile')
              ..adapter('caddyfile'),
          ),
        ),
    );

    log.info('All sites deployed.');
  }
}
