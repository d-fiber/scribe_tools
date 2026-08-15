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

import '../../../../../core/logger.dart';
import '../../../../../ops/config.dart';
import '../../../../../ops/env_file.dart';
import '../../../../../ops/secrets.dart';

/// Les seuls comptes SMTP qui deviennent des variables d'environnement.
///
/// Tout autre compte declare dans config.yaml est une ligne de
/// internal_t__smtp_accounts, jamais une variable d'env : ces deux noms-la
/// sont fixes par le SDK, pas par le projet. `env.dart` s'en sert pour emettre
/// les accesseurs `SMTP_<NOM>_*` correspondants, et le docker-compose les
/// reference en dur puisqu'ils ne dependent pas du projet.
const Set<String> foundationSmtpAccounts = <String>{'account', 'noreply'};

const List<String> smtpFields = <String>['HOST', 'PORT', 'USER', 'PASS'];

Future<void> generateSmtpAccounts() async {
  const Log log = Log('gen');
  final Map<String, Map<String, String>> accounts = Config.read().getSmtpAccounts();
  final List<String> names = accounts.keys.where(foundationSmtpAccounts.contains).toList()..sort();

  if (EnvFile.read('SMTP_ENCRYPTION_KEY').isEmpty) {
    EnvFile.write('SMTP_ENCRYPTION_KEY', Secrets.randBase64(32));
  }

  for (final String name in names) {
    final Map<String, String> account = accounts[name]!;
    for (final String field in smtpFields) {
      EnvFile.write('SMTP_${name.toUpperCase()}_$field', account[field.toLowerCase()]!);
    }
  }

  _writeGotrueAccount(names, accounts);

  final Iterable<String> extra = accounts.keys.where((String n) => !foundationSmtpAccounts.contains(n));
  if (extra.isNotEmpty) {
    log.warn(
      'ignored SMTP account(s) in config: ${extra.join(", ")} — '
      'extra accounts are rows in internal_t__smtp_accounts, use public.upsert_smtp_account().',
    );
  }

  log.info('${names.length} baseline SMTP account(s) (${names.join(", ")}) → .env');
}

String? primarySmtpAccount(List<String> names) {
  if (names.isEmpty) return null;
  return names.contains('noreply') ? 'noreply' : names.first;
}

void _writeGotrueAccount(List<String> names, Map<String, Map<String, String>> accounts) {
  const Log log = Log('gen');
  final String? primary = primarySmtpAccount(names);
  if (primary == null) {
    log.warn('no baseline SMTP account in config: GoTrue will not be able to send mail.');
    return;
  }

  final Map<String, String> account = accounts[primary]!;
  for (final String field in smtpFields) {
    EnvFile.write('GOTRUE_SMTP_$field', account[field.toLowerCase()]!);
  }
  EnvFile.write('GOTRUE_SMTP_ADMIN_EMAIL', account['user']!);

  log.info('GoTrue SMTP → $primary account');
}
