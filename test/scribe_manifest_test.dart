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

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:test/test.dart';

const String _minimal = '''
name: "notes"
url: "https://notes.example.com"
email: "dev@notes.example.com"

dependencies:
  - security/auth
  - security/rbac

api:
  config:
    origins:
      - "https://notes.example.com"
    allowed_countries: ["FR"]
''';

late MemoryFileSystem fs;

Future<T> withEnvironment<T>(Map<String, String> environment, T Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Platform: () => FakePlatform(environment: environment),
  },
  body: body,
);

ScribeManifest manifestOf(String yaml) {
  final File file = fs.file('/notes/config.yaml')..createSync(recursive: true);
  file.writeAsStringSync(yaml);
  return ScribeManifest.load(file);
}

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  test('a minimal manifest is complete and reads its fields', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf(_minimal);

      expect(manifest.problems, isEmpty);
      expect(manifest.isComplete, isTrue);
      expect(manifest.name, 'notes');
      expect(manifest.dependencies, <String>['security/auth', 'security/rbac']);
      expect(manifest.allowedCountries, <String>['FR']);
    });
  });

  test('a missing required field is named, not guessed', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf(_minimal.replaceFirst('email: "dev@notes.example.com"', 'email: ""'));

      expect(manifest.problems.map((ManifestProblem p) => p.field), contains('email'));
    });
  });

  test('an origin with a path is refused', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf(
        _minimal.replaceFirst('      - "https://notes.example.com"', '      - "https://notes.example.com/api"'),
      );

      expect(manifest.problems.map((ManifestProblem p) => p.field), contains('api.config.origins'));
    });
  });

  test('a secret written in clear is refused, and the fix is named', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf('''
$_minimal
integrations:
  twilio:
    auth_token: "a-real-token"
''');

      final ManifestProblem problem = manifest.problems.singleWhere(
        (ManifestProblem p) => p.field == 'integrations.twilio.auth_token',
      );

      expect(problem.reason, contains('env(TWILIO_AUTH_TOKEN)'));
    });
  });

  test('a secret held by reference passes, and resolves from the environment', () async {
    await withEnvironment(const <String, String>{'TWILIO_AUTH_TOKEN': 'from-the-environment'}, () {
      final ScribeManifest manifest = manifestOf('''
$_minimal
integrations:
  twilio:
    auth_token: env(TWILIO_AUTH_TOKEN)
''');

      expect(manifest.problems, isEmpty);
      expect(manifest.read(<String>['integrations', 'twilio', 'auth_token']), 'env(TWILIO_AUTH_TOKEN)');
      expect(
        manifest.resolve('env(TWILIO_AUTH_TOKEN)', field: 'integrations.twilio.auth_token'),
        'from-the-environment',
      );
    });
  });

  test('a reference to a variable nobody set fails by name', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf(_minimal);

      expect(
        () => manifest.resolve('env(TWILIO_AUTH_TOKEN)', field: 'integrations.twilio.auth_token'),
        throwsA(
          isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains('TWILIO_AUTH_TOKEN')),
        ),
      );
    });
  });

  test('an empty secret field is not a problem, it is just unset', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf('''
$_minimal
integrations:
  twilio:
    auth_token: ""
''');

      expect(manifest.problems, isEmpty);
    });
  });
}
