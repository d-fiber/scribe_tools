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

import 'dart:convert';
import 'dart:io';

import 'package:change_case/change_case.dart';

import '../core/paths/infra_files.dart';
import 'config.dart';
import 'secrets.dart';

class EnvFile {
  static File get _file => InfraFiles.tree.alchemy.ops.env;

  static bool exists() => _file.existsSync();

  static void delete() {
    if (_file.existsSync()) _file.deleteSync();
  }

  static String read(String key) {
    if (!_file.existsSync()) return '';
    for (final String line in _file.readAsLinesSync()) {
      if (line.startsWith('$key=')) return line.substring(key.length + 1);
    }
    return '';
  }

  static void write(String key, String value) {
    _file.parent.createSync(recursive: true);
    final List<String> lines = _file.existsSync()
        ? _file.readAsLinesSync()
        : <String>[];
    final int index = lines.indexWhere(
      (String line) => line.startsWith('$key='),
    );
    final String newLine = '$key=$value';
    if (index == -1) {
      lines.add(newLine);
    } else {
      lines[index] = newLine;
    }
    final File staged = File('${_file.path}.tmp');
    staged.writeAsStringSync('${lines.join('\n')}\n');
    staged.renameSync(_file.path);
  }

  static Future<void> generate(Config cfg) async {
    final ProjectUrls urls = deriveUrls(cfg.get('URL'));
    final String jwtSecret = Secrets.randBase64(64);
    final String jwtIssuer = cfg.get('NAME').toSnakeCase();
    final String wgPass = Secrets.randAlnum(24);
    final X25519KeyPair deviceKeyPair = await Secrets.x25519Keypair();

    String optKeys = '';
    final String publishable = cfg.get('SUPABASE_PUBLISHABLE_KEY');
    final String secretKey = cfg.get('SUPABASE_SECRET_KEY');
    if (publishable.isNotEmpty && secretKey.isNotEmpty) {
      optKeys =
          '\nSUPABASE_PUBLISHABLE_KEY=$publishable\nSUPABASE_SECRET_KEY=$secretKey';
    }

    String optFcm = '';
    final String fcmProjectId = cfg.get('FCM_PROJECT_ID');
    final String fcmClientEmail = cfg.get('FCM_CLIENT_EMAIL');
    final String fcmPrivateKey = cfg.get('FCM_PRIVATE_KEY');
    if (fcmProjectId.isNotEmpty &&
        fcmClientEmail.isNotEmpty &&
        fcmPrivateKey.isNotEmpty) {
      optFcm =
          '\nFCM_PROJECT_ID=$fcmProjectId\nFCM_CLIENT_EMAIL=$fcmClientEmail\nFCM_PRIVATE_KEY=$fcmPrivateKey';
    }

    String optS3 = '';
    final String s3Bucket = cfg.get('S3_BUCKET');
    final String s3Endpoint = cfg.get('S3_ENDPOINT');
    final String s3AccessKey = cfg.get('S3_ACCESS_KEY');
    final String s3SecretKey = cfg.get('S3_SECRET_KEY');
    if (s3Bucket.isNotEmpty && s3Endpoint.isNotEmpty && s3AccessKey.isNotEmpty && s3SecretKey.isNotEmpty) {
      optS3 =
          '\nSTORAGE_BACKEND=s3\nIMGPROXY_USE_S3=true'
          '\nS3_BUCKET=$s3Bucket\nS3_ENDPOINT=$s3Endpoint'
          '\nS3_REGION=${cfg.get('S3_REGION')}'
          '\nS3_ACCESS_KEY=$s3AccessKey\nS3_SECRET_KEY=$s3SecretKey';
    }

    String optBackup = '';
    final String backupBucket = cfg.get('BACKUP_BUCKET');
    final String backupEndpoint = cfg.get('BACKUP_ENDPOINT');
    final String backupAccessKey = cfg.get('BACKUP_ACCESS_KEY');
    final String backupSecretKey = cfg.get('BACKUP_SECRET_KEY');
    if (backupBucket.isNotEmpty &&
        backupEndpoint.isNotEmpty &&
        backupAccessKey.isNotEmpty &&
        backupSecretKey.isNotEmpty) {
      optBackup =
          '\nPGBACKREST_ARCHIVE_MODE=on\nPGBACKREST_REPO_TYPE=s3'
          '\nPGBACKREST_BUCKET=$backupBucket\nPGBACKREST_ENDPOINT=$backupEndpoint'
          '\nPGBACKREST_REGION=${cfg.get('BACKUP_REGION')}'
          '\nPGBACKREST_KEY=$backupAccessKey\nPGBACKREST_KEY_SECRET=$backupSecretKey';
    }

    String optTwilio = '';
    final String twilioAccountSid = cfg.get('TWILIO_ACCOUNT_SID');
    final String twilioAuthToken = cfg.get('TWILIO_AUTH_TOKEN');
    final String twilioMessageServiceSid = cfg.get(
      'TWILIO_MESSAGE_SERVICE_SID',
    );
    if (twilioAccountSid.isNotEmpty &&
        twilioAuthToken.isNotEmpty &&
        twilioMessageServiceSid.isNotEmpty) {
      optTwilio =
          '\nTWILIO_ACCOUNT_SID=$twilioAccountSid\nTWILIO_AUTH_TOKEN=$twilioAuthToken\nTWILIO_MESSAGE_SERVICE_SID=$twilioMessageServiceSid';
    }

    String optGoogle = '';
    final String googleClientId = cfg.get('GOOGLE_CLIENT_ID');
    final String googleClientSecret = cfg.get('GOOGLE_CLIENT_SECRET');
    if (googleClientId.isNotEmpty && googleClientSecret.isNotEmpty) {
      optGoogle =
          '\nGOOGLE_CLIENT_ID=$googleClientId\nGOOGLE_CLIENT_SECRET=$googleClientSecret\nGOOGLE_ADDITIONAL_CLIENT_IDS=${cfg.get('GOOGLE_ADDITIONAL_CLIENT_IDS')}';
    }

    String optApple = '';
    final String appleClientId = cfg.get('APPLE_CLIENT_ID');
    final String appleClientSecret = cfg.get('APPLE_CLIENT_SECRET');
    if (appleClientId.isNotEmpty && appleClientSecret.isNotEmpty) {
      optApple =
          '\nAPPLE_CLIENT_ID=$appleClientId\nAPPLE_CLIENT_SECRET=$appleClientSecret\nAPPLE_ADDITIONAL_CLIENT_IDS=${cfg.get('APPLE_ADDITIONAL_CLIENT_IDS')}';
    }

    final String dashboardPass = Secrets.randBase64(32);
    final String dashboardBasicAuth = base64.encode(
      utf8.encode('admin:$dashboardPass'),
    );
    final String wgPassHash = (await Secrets.bcryptHash(
      wgPass,
    )).replaceAll(r'$', r'$$');

    final String content =
        '''
# ── Identity ─────────────────────────────────────────────────────────────────
APP_NAME=${cfg.get('NAME')}
APP_NAME_SNAKE=$jwtIssuer
ACME_EMAIL=${cfg.get('EMAIL')}

# ── URLs ─────────────────────────────────────────────────────────────────────
MAIN_URL=${urls.main}
ADMIN_URL=${urls.admin}
APP_URL=${urls.app}
INTRA_URL=${urls.intra}

# ── Internal addresses. Override them for a deployment spread over several
# ── machines: Postgres triggers and GoTrue call the compute tier back on these.
API_INTERNAL_URL=http://api:3000
FUNCTIONS_INTERNAL_URL=http://functions:9000
VPN_DOMAIN=${urls.vpnDomain}

# ── Dashboard ─────────────────────────────────────────────────────────────────
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=$dashboardPass
DASHBOARD_BASIC_AUTH=$dashboardBasicAuth

# ── SMTP (per-account SMTP_<NAME>_* written by `gen code` see
# ── smtp_accounts.dart) ─────────────────────────────────────────────────────────

# ── APIs tierces ──────────────────────────────────────────────────────────────
GEOCODING_API_KEY=${cfg.get('GEOCODING_API_KEY')}$optFcm$optTwilio$optGoogle$optApple$optS3$optBackup

# ── PostgreSQL ────────────────────────────────────────────────────────────────
POSTGRES_PASSWORD=${Secrets.randAlnum(32)}

# ── Redis ─────────────────────────────────────────────────────────────────────
REDIS_PASSWORD=${Secrets.randAlnum(32)}

# ── JWT ───────────────────────────────────────────────────────────────────────
JWT_SECRET=$jwtSecret
ANON_KEY=${Secrets.generateJwt('anon', jwtSecret, issuer: jwtIssuer)}
SERVICE_KEY=${Secrets.generateJwt('service_role', jwtSecret, issuer: jwtIssuer)}$optKeys

# ── Crypto / Sessions ─────────────────────────────────────────────────────────
SECRET_KEY_BASE=${Secrets.randBase64(64)}
DB_ENC_KEY=${Secrets.randAlnum(16)}

# ── VPN ───────────────────────────────────────────────────────────────────────
WG_EASY_PASSWORD=$wgPass
WG_EASY_PASSWORD_HASH=$wgPassHash

# ── Hooks ─────────────────────────────────────────────────────────────────────
HOOK_SEND_EMAIL_SECRETS=${Secrets.hookSecret()}
HOOK_SEND_SMS_SECRETS=${Secrets.hookSecret()}
HOOK_PASSWORD_SECRETS=${Secrets.hookSecret()}
HOOK_MFA_SECRETS=${Secrets.hookSecret()}
HOOK_CUSTOM_ACCESS_TOKEN_SECRETS=${Secrets.hookSecret()}

# ── Secrets applicatifs ───────────────────────────────────────────────────────
INTERNAL_SECRET=${Secrets.randBase64(32)}
PENDING_TOKEN_SECRET=${Secrets.randBase64(48)}

# ── Application keys, for the admin API and the app API ──────────────────────
ADMIN_APP_KEYS=${Secrets.randBase64(32)}
APP_KEYS=${Secrets.randBase64(32)}

# ── Device payload X25519 ───────────────────────────────────────────────────
DEVICE_PAYLOAD_PRIVATE_KEY=${deviceKeyPair.privateKeyHex}
DEVICE_PAYLOAD_PUBLIC_KEY=${deviceKeyPair.publicKeyHex}

# ── Config fingerprint every other command checks this against the current
# ── config.yaml (NAME/URL) and refuses to run on a mismatch. Do not edit.
CONFIG_FINGERPRINT=${cfg.fingerprint}
''';

    await InfraFiles.tree.env.writeAsString(content);
  }
}
