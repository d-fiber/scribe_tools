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
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dage/dage.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';

const String kIdentityVariable = 'SCRIBE_AGE_KEY';

const String kIdentityPrefix = 'AGE-SECRET-KEY-';

const String kRecipientPrefix = 'age';

final RegExp secretName = RegExp(r'^[A-Z][A-Z0-9_]*$');

class SecretsStore {
  const SecretsStore({required this.file, required this.keyFile});

  static const String fileName = 'secrets.age';

  static SecretsStore forProject(Project project) => SecretsStore(
    file: project.directory.childFile(fileName),
    keyFile: globals.fs.file(p.join(_configHome(), 'scribe', 'keys.txt')),
  );

  static String _configHome() {
    final Map<String, String> environment = globals.platform.environment;
    final String? explicit = environment['XDG_CONFIG_HOME'];
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final String? home = environment['HOME'];
    if (home == null || home.isEmpty) {
      throwToolExit('Neither XDG_CONFIG_HOME nor HOME is set, so there is nowhere to keep the key.');
    }

    return p.join(home, '.config');
  }

  final File file;
  final File keyFile;

  bool get exists => file.existsSync();

  List<String> get identityLines {
    final List<String> blocks = <String>[
      if (globals.platform.environment[kIdentityVariable] case final String inline) inline,
      if (keyFile.existsSync()) keyFile.readAsStringSync(),
    ];

    return <String>[
      for (final String block in blocks)
        for (final String line in block.split('\n'))
          if (line.trim().toUpperCase().startsWith(kIdentityPrefix))
            line.trim().toUpperCase(),
    ];
  }

  Future<List<AgeKeyPair>> identities() async => <AgeKeyPair>[
    for (final String line in identityLines) await AgePlugin.convertIdentityToKeyPair(AgeIdentity.fromBech32(line)),
  ];

  Future<AgeKeyPair> createKey() async {
    final SimpleKeyPair pair = await X25519().newKeyPair();
    final AgeIdentity identity = AgeIdentity(
      kIdentityPrefix,
      Uint8List.fromList(await pair.extractPrivateKeyBytes()),
    );
    final AgeRecipient recipient = AgeRecipient(
      kRecipientPrefix,
      Uint8List.fromList((await pair.extractPublicKey()).bytes),
    );

    await keyFile.parent.create(recursive: true);
    final String previous = keyFile.existsSync() ? keyFile.readAsStringSync() : '';
    await keyFile.writeAsString('${previous.trimRight()}\n$identity\n'.trimLeft());

    return AgeKeyPair(identity, recipient);
  }

  Future<Map<String, String>> read() async {
    if (!exists) return <String, String>{};

    final List<AgeKeyPair> keys = await identities();
    if (keys.isEmpty) {
      throwToolExit(
        '${file.path} is encrypted, and no key can open it.\n'
        'Put the identity in ${keyFile.path}, or in $kIdentityVariable.',
      );
    }

    try {
      final List<List<int>> decrypted = await decrypt(file.openRead(), keys).toList();
      return _parse(utf8.decode(decrypted.flattened.toList()));
    } on Exception {
      throwToolExit(
        '${file.path} could not be opened with any known key.\n'
        'The key that wrote it is not in ${keyFile.path} nor in $kIdentityVariable.',
      );
    }
  }

  Future<void> write(Map<String, String> secrets, {required AgeRecipient recipient}) async {
    final String body = _render(secrets);
    final Uint8List payload = Uint8List.fromList(utf8.encode(body));

    final List<List<int>> sealed = await encrypt(Stream<List<int>>.value(payload), <AgeRecipient>[recipient]).toList();

    await file.writeAsBytes(sealed.flattened.toList());
  }

  Future<AgeRecipient> recipientOf() async {
    if (!exists) return (await createKey()).recipient;

    final List<AgeKeyPair> keys = await identities();
    for (final AgeKeyPair candidate in keys) {
      try {
        await decrypt(file.openRead(), <AgeKeyPair>[candidate]).toList();
        return candidate.recipient;
      } on Exception {
        continue;
      }
    }

    throwToolExit(
      '${file.path} could not be opened with any known key.\n'
      'The key that wrote it is not in ${keyFile.path} nor in $kIdentityVariable.',
    );
  }

  static Map<String, String> _parse(String body) {
    final Map<String, String> secrets = <String, String>{};

    for (final String line in body.split('\n')) {
      final String entry = line.trim();
      if (entry.isEmpty) continue;

      final int separator = entry.indexOf('=');
      if (separator <= 0) continue;

      secrets[entry.substring(0, separator)] = entry.substring(separator + 1);
    }

    return secrets;
  }

  static String _render(Map<String, String> secrets) {
    final List<String> names = secrets.keys.toList()..sort();

    return <String>[for (final String name in names) '$name=${secrets[name]}'].join('\n');
  }
}

class SecretAssignment {
  const SecretAssignment(this.name, this.value);

  static SecretAssignment parse(String raw) {
    final int separator = raw.indexOf('=');
    if (separator <= 0) {
      throwUsageError('--set expects NAME=VALUE, got "$raw".', command: 'secrets');
    }

    final String name = raw.substring(0, separator).trim();
    if (!secretName.hasMatch(name)) {
      throwUsageError(
        '"$name" is not a secret name — use uppercase letters, digits and underscore, starting with a letter.',
        command: 'secrets',
      );
    }

    return SecretAssignment(name, raw.substring(separator + 1));
  }

  final String name;
  final String value;
}
