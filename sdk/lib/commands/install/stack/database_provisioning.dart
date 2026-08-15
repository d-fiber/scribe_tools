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

import '../../../core/commands/base/curl.dart';
import '../../../core/commands/psql/cast.dart';
import '../../../core/commands/psql/conditions.dart';
import '../../../core/commands/psql/function_call.dart';
import '../../../core/commands/psql/functions.dart';
import '../../../core/commands/psql/sql.dart';
import '../../../core/process.dart';
import '../../../ops/compose.dart';
import '../../../ops/env_file.dart';
import '../../../ops/project_command.dart';
import '../support.dart';

mixin DatabaseProvisioning on ProjectCommand {
  Future<bool> _setUpSearcherIndices() async {
    final Curl setup = Curl()
      ..silent()
      ..failFast()
      ..request('POST')
      ..url('http://localhost:9000/searcher/setup')
      ..header('x-internal-secret: ${EnvFile.read('INTERNAL_SECRET')}');

    for (int attempt = 1; attempt <= 5; attempt++) {
      final ProcessResult result = await Compose.capture(
        (await Compose.docker())
          ..exec()
          ..noTty()
          ..service('functions')
          ..command(commandArgv(setup)),
      );
      if (result.exitCode == 0) return true;
      if (attempt < 5) {
        log.warn('Searcher setup not ready, retrying in 3s... ($attempt/5)');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    return false;
  }

  Future<void> provision() async {
    log.info('Setting up Searcher indices...');
    final bool searcherOk = await _setUpSearcherIndices();
    if (!searcherOk) log.warn('Searcher setup failed run it manually.');

    log.info('Patching auth.users token columns...');
    await Compose.run(
      await psqlCompose(
        Sql()
          ..updateTable('auth.users')
          ..set('email_confirmed_at', coalesce([Raw('email_confirmed_at'), Raw('created_at')]))
          ..set('email_change_token_new', coalesce([Raw('email_change_token_new'), Raw("''")]))
          ..set('email_change', coalesce([Raw('email_change'), Raw("''")]))
          ..set('email_change_token_current', coalesce([Raw('email_change_token_current'), Raw("''")]))
          ..where(
            Or([
              IsNull(Raw('email_confirmed_at')),
              IsNull(Raw('email_change_token_new')),
              IsNull(Raw('email_change')),
              IsNull(Raw('email_change_token_current')),
            ]),
          ),
      ),
    );

    log.info('Seeding auth identities for dev users...');
    await Compose.capture(
      await psqlCompose(
        Sql()
          ..insertInto('auth.identities', [
            'id',
            'user_id',
            'provider_id',
            'provider',
            'identity_data',
            'last_sign_in_at',
            'created_at',
            'updated_at',
          ])
          ..select([
            genRandomUuid(),
            Raw('u.id'),
            Raw('u.email'),
            Raw("'email'"),
            jsonbBuildObject([
              Raw("'sub'"),
              Cast(Raw('u.id'), 'text'),
              Raw("'email'"),
              Raw('u.email'),
              Raw("'email_verified'"),
              Raw('true'),
            ]),
            now(),
            now(),
            now(),
          ])
          ..from('auth.users', alias: 'u')
          ..where(
            NotExists(
              Sql()
                ..select([Raw('1')])
                ..from('auth.identities', alias: 'i')
                ..where(And([Eq(Raw('i.user_id'), Raw('u.id')), Eq(Raw('i.provider'), Raw("'email'"))])),
            ),
          ),
      ),
    );

    log.info('Waiting for public.admins table...');
    await waitUntil(
      log,
      'public.admins',
      Compose.command(
        await psqlCompose(
          Sql()
            ..select([Raw('1')])
            ..from('public.admins')
            ..limit(0),
        ),
      ),
      timeout: 180,
    );

    log.info('Provisioning VPN for admins...');
    final ProcessResult vpnResult = await Compose.capture(
      await psqlCompose(
        Sql()
          ..select([
            FunctionCall('net.http_post')
              ..namedArg('url', Raw("'http://functions:9000/vpn/create'"))
              ..namedArg(
                'body',
                jsonbBuildObject([
                  Raw("'admin_id'"),
                  Cast(Raw('admin_id'), 'text'),
                  Raw("'email'"),
                  Raw('email'),
                  Raw("'role'"),
                  Raw('role'),
                ]),
              )
              ..namedArg(
                'headers',
                jsonbBuildObject([
                  Raw("'Content-Type'"),
                  Raw("'application/json'"),
                  Raw("'x-internal-secret'"),
                  currentSetting(Raw("'app.settings.internal_secret'")),
                ]),
              )
              ..namedArg('timeout_milliseconds', Raw('10000')),
          ])
          ..from('public.admins')
          ..where(IsNull(Raw('vpn_client_id'))),
      ),
    );
    if (vpnResult.exitCode != 0) {
      log.warn('VPN provisioning failed trigger it manually.');
    }
  }
}
