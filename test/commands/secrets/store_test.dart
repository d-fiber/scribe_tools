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

import 'package:dage/dage.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/commands/secrets/store.dart';
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

SecretsStore storeIn(String root) =>
    SecretsStore(file: fs.file('$root/${SecretsStore.fileName}'), keyFile: fs.file('/home/.config/scribe/keys.txt'));

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

  test('a value holding a newline survives the round trip', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      const String value = 'line1\nline2';

      await store.write(<String, String>{'TOKEN': value}, recipient: await store.recipientOf());

      expect((await store.read())['TOKEN'], value);
    });
  });

  test('a value holding a backslash survives the round trip, newline or not', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      const String value = r'C:\path\to\thing';

      await store.write(<String, String>{'TOKEN': value}, recipient: await store.recipientOf());

      expect((await store.read())['TOKEN'], value);
    });
  });

  test('a second secret after one holding a newline is not swallowed by it', () async {
    await withHome(() async {
      final SecretsStore store = storeIn('/work/notes');
      const Map<String, String> secrets = <String, String>{'A': 'line1\nline2', 'B': '2'};

      await store.write(secrets, recipient: await store.recipientOf());

      expect(await store.read(), secrets);
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
