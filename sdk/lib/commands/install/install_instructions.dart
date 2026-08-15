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

import '../../ops/config.dart';
import '../../ops/env_file.dart';
import '../../ops/project_command.dart';

mixin InstallInstructions on ProjectCommand {
  String _firstAppKey(String field) => EnvFile.read(field).split(',').first;

  void _printFlutterRunInstructions({
    required String label,
    required String url,
    required String appKeyFlag,
    required String appKeyField,
  }) {
    print('$label:');
    print('flutter run');
    print('  --dart-define=SUPABASE_URL=$url');
    print('  --dart-define=$appKeyFlag=${_firstAppKey(appKeyField)}');
    print(
      '  --dart-define=DEVICE_PAYLOAD_PUBLIC_KEY=${EnvFile.read('DEVICE_PAYLOAD_PUBLIC_KEY')}',
    );
  }

  void printInstructions(Config cfg) {
    final ProjectUrls urls = deriveUrls(cfg.get('URL'));
    log.info('Done! Infrastructure is up.');
    print('');
    _printFlutterRunInstructions(
      label: 'Admin (desktop)',
      url: urls.admin,
      appKeyFlag: 'ADMIN_APP_KEY',
      appKeyField: 'ADMIN_APP_KEYS',
    );
    print('');
    _printFlutterRunInstructions(
      label: 'App (mobile)',
      url: urls.app,
      appKeyFlag: 'APP_KEY',
      appKeyField: 'APP_KEYS',
    );
  }
}
