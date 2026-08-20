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

import 'package:dage/dage.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/secrets.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Future<T> withHome<T>(Future<T> Function() body, {String? identity}) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Platform: () => FakePlatform(
      environment: <String, String>{
        'XDG_CONFIG_HOME': '/home/.config',
        if (identity case final String key) kIdentityVariable: key,
      },
    ),
  },
  body: body,
);

SecretsStore storeIn(String root) => SecretsStore(
  file: fs.file('$root/${SecretsStore.fileName}'),
  keyFile: fs.file('/home/.config/scribe/keys.txt'),
);

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
  });

  test('a fresh store answers empty rather than failing', () async {
    await withHome(() async {
      expect(await storeIn('/work/notes').read(), isEmpty);
    });
  });

  test('what is written comes back, and the file on disk is not readable', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      final AgeRecipient recipient = await store.recipientOf();

      await store.write(<String, String>{'TWILIO_AUTH_TOKEN': 'abc123'}, recipient: recipient);

      expect(await store.read(), <String, String>{'TWILIO_AUTH_TOKEN': 'abc123'});
      final List<int> onDisk = store.file.readAsBytesSync();
      expect(String.fromCharCodes(onDisk.take(21)), 'age-encryption.org/v1');
      expect(String.fromCharCodes(onDisk), isNot(contains('abc123')));
    });
  });

  test('the key is written once and reused, never regenerated', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');

      await store.write(<String, String>{'A': '1'}, recipient: await store.recipientOf());
      final String first = store.keyFile.readAsStringSync();

      await store.write(<String, String>{'A': '1', 'B': '2'}, recipient: await store.recipientOf());

      expect(store.keyFile.readAsStringSync(), first);
      expect(await store.read(), <String, String>{'A': '1', 'B': '2'});
    });
  });

  test('a store nobody holds the key for fails by name', () async {
    late List<int> sealed;

    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      await store.write(<String, String>{'A': '1'}, recipient: await store.recipientOf());
      sealed = store.file.readAsBytesSync();
    });

    fs.file('/home/.config/scribe/keys.txt').deleteSync();
    fs.file('/work/notes/${SecretsStore.fileName}').writeAsBytesSync(sealed);

    await withHome(() async {
      expect(
        () => storeIn('/work/notes').read(),
        throwsA(isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains(kIdentityVariable))),
      );
    });
  });

  test('an identity passed through the environment opens the store', () async {
    late String identity;

    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      await store.write(<String, String>{'A': '1'}, recipient: await store.recipientOf());
      identity = store.keyFile.readAsStringSync().trim();
    });

    fs.file('/home/.config/scribe/keys.txt').deleteSync();

    await withHome(() async {
      expect(await storeIn('/work/notes').read(), <String, String>{'A': '1'});
    }, identity: identity);
  });

  test('a value holding an equals sign survives the round trip', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      const String value = 'a=b=c==';

      await store.write(<String, String>{'TOKEN': value}, recipient: await store.recipientOf());

      expect((await store.read())['TOKEN'], value);
    });
  });

  group('SecretAssignment', () {
    test('it splits on the first equals sign only', () {
      final SecretAssignment assignment = SecretAssignment.parse('TOKEN=a=b');

      expect(assignment.name, 'TOKEN');
      expect(assignment.value, 'a=b');
    });

    test('a lowercase or dashed name is refused', () {
      expect(() => SecretAssignment.parse('bad-name=x'), throwsA(isA<UsageError>()));
      expect(() => SecretAssignment.parse('token=x'), throwsA(isA<UsageError>()));
    });

    test('a value without a name is refused', () {
      expect(() => SecretAssignment.parse('=x'), throwsA(isA<UsageError>()));
      expect(() => SecretAssignment.parse('TOKEN'), throwsA(isA<UsageError>()));
    });
  });
}
