// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

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

packages:
  - auth
  - audience

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
  final File file = fs.file('/notes/config.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync(yaml);
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
      expect(manifest.packages, <String>['auth', 'audience']);
      expect(manifest.allowedCountries, <String>['FR']);
    });
  });

  test('a manifest that still spells the key dependencies mounts the same packages', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf(_minimal.replaceFirst('packages:', 'dependencies:'));

      expect(manifest.packages, <String>['auth', 'audience']);
    });
  });

  test('packages wins over dependencies when a manifest carries both', () async {
    await withEnvironment(const <String, String>{}, () {
      final ScribeManifest manifest = manifestOf('$_minimal\ndependencies:\n  - storage\n');

      expect(manifest.packages, <String>['auth', 'audience']);
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
        throwsA(isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains('TWILIO_AUTH_TOKEN'))),
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
