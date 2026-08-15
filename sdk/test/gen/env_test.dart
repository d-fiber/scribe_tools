import 'dart:io';

import 'package:sdk/commands/gen/code/generators/config/env.dart';
import 'package:sdk/commands/gen/code/generators/seeds/smtp_accounts.dart';
import 'package:test/test.dart';

File _composeWith(Directory dir, String name, String body) =>
    File('${dir.path}/$name')..writeAsStringSync(body);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('env_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('readComposeEnvNames', () {
    test('reads the env var names declared for the service', () {
      final File compose = _composeWith(dir, 'docker-compose.yaml', '''
services:
  api:
    environment:
      APP_URL: "https://example.com"
      PORT: "3000"
  db:
    environment:
      NOT_FOR_API: "x"
''');

      expect(readComposeEnvNames(<File>[compose], 'api'), <String>['APP_URL', 'PORT']);
    });

    test('an unrendered {{placeholder}} never becomes an accessor', () {
      final File compose = _composeWith(dir, 'docker-compose.smtp.yaml', '''
services:
  api:
    environment:
      {{smtps}}
''');

      expect(readComposeEnvNames(<File>[compose], 'api'), isEmpty);
    });

    test('a missing service is not an error', () {
      final File compose = _composeWith(dir, 'docker-compose.yaml', '''
services:
  db:
    environment:
      SOMETHING: "1"
''');

      expect(readComposeEnvNames(<File>[compose], 'api'), isEmpty);
    });
  });

  group('smtpEnvNames', () {
    test('emits four accessors per foundation account, sorted by account', () {
      expect(smtpEnvNames(), <String>[
        'SMTP_ACCOUNT_HOST',
        'SMTP_ACCOUNT_PORT',
        'SMTP_ACCOUNT_USER',
        'SMTP_ACCOUNT_PASS',
        'SMTP_NOREPLY_HOST',
        'SMTP_NOREPLY_PORT',
        'SMTP_NOREPLY_USER',
        'SMTP_NOREPLY_PASS',
      ]);
    });

    test('covers exactly the accounts that smtp_accounts.dart writes to .env', () {
      expect(smtpEnvNames().length, foundationSmtpAccounts.length * 4);
    });

    test('every name is a valid environment variable identifier', () {
      for (final String name in smtpEnvNames()) {
        expect(name, matches(RegExp(r'^[A-Z][A-Z0-9_]*$')));
      }
    });
  });
}
