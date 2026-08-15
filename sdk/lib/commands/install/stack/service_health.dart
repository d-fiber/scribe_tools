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

import '../../../core/commands/base/curl.dart';
import '../../../core/commands/base/sh.dart';
import '../../../core/commands/docker.dart';
import '../../../core/commands/psql/sql.dart';
import '../../../core/process.dart';
import '../../../ops/compose.dart';
import '../../../ops/config.dart';
import '../../../ops/env_file.dart';
import '../../../ops/project_command.dart';
import '../support.dart';

mixin ServiceHealth on ProjectCommand {
  Future<void> waitForServices(Config cfg) async {
    log.info('Waiting for vpn-admins...');
    await waitUntil(
      log,
      'vpn-admins',
      Compose.command(
        (await Compose.docker())
          ..exec()
          ..noTty()
          ..service('vpn-admins')
          ..command([
            'node',
            '-e',
            "require('http').get('http://localhost:51821/',r=>r.statusCode<500?process.exit(0):process.exit(1)).on('error',()=>process.exit(1))",
          ]),
      ),
    );

    final ProjectUrls urls = deriveUrls(cfg.get('URL'));
    final String wgPass = EnvFile.read('WG_EASY_PASSWORD');
    print('');
    log.info('VPN  →  ${urls.intra}/vpn   password: $wgPass');
    print('');

    log.info('Waiting for auth DB...');
    await waitUntil(
      log,
      'auth DB',
      Compose.command(
        await psqlCompose(
          Sql()
            ..select([Raw('email_change_token_new')])
            ..from('auth.users')
            ..limit(0),
        ),
      ),
      timeout: 180,
    );

    log.info('Waiting for OpenSearch...');
    final Curl searcherHealth = Curl()
      ..silent()
      ..failFast()
      ..url('http://localhost:9200/_cluster/health');
    await waitUntil(
      log,
      'OpenSearch',
      commandArgv(
        Docker()
          ..exec()
          ..container('opensearch')
          ..command(commandArgv(searcherHealth)),
        asPrivileged: true,
      ),
    );

    log.info('Waiting for edge functions...');
    final Sh functionsHealth = Sh()
      ..c()
      ..script('(echo > /dev/tcp/localhost/9000) 2>/dev/null');
    await waitUntil(
      log,
      'functions',
      Compose.command(
        (await Compose.docker())
          ..exec()
          ..noTty()
          ..service('functions')
          ..command(commandArgv(functionsHealth)),
      ),
    );
  }
}
