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

import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dage/dage.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';

/// The variable an age identity can be handed through instead of a key file.
///
/// This is what a CI run uses: it has no home directory to keep a file in.
const String kIdentityVariable = 'SCRIBE_AGE_KEY';

/// The bech32 prefix of an age private key.
const String kIdentityPrefix = 'AGE-SECRET-KEY-';

/// The bech32 prefix of an age public key.
const String kRecipientPrefix = 'age';

/// The shape of a secret's name: uppercase, digits and underscore, opening on a letter.
final RegExp secretName = RegExp(r'^[A-Z][A-Z0-9_]*$');

/// A project's `secrets.age`, and the keys that open it.
///
/// The file is committed and the key is not. Encryption is age, so a project
/// can be handed several recipients later without the format changing.
///
/// A key is looked for in two places, [kIdentityVariable] first and the key
/// file second, and every identity found is tried. That is what lets a machine
/// hold the key of more than one project at once.
class SecretsStore {
  /// Opens [file] with the identities [keyFile] holds.
  const SecretsStore({required this.file, required this.keyFile});

  /// The name of the encrypted file, at the root of a project.
  static const String fileName = 'secrets.age';

  /// The store of [project], with the key file this machine keeps its identities in.
  ///
  /// The key file sits under `XDG_CONFIG_HOME`, or under `~/.config` when that
  /// is unset, outside the project, so it is never committed by accident.
  ///
  /// Throws a [ToolExit] when neither variable is set, since there is then
  /// nowhere to keep a key.
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

  /// The encrypted file, `secrets.age` at the root of the project.
  final File file;

  /// The file this machine keeps its age identities in, one per line.
  final File keyFile;

  /// Whether this project has a `secrets.age` yet.
  bool get exists => file.existsSync();

  /// Every age private key this machine can offer, the environment's first.
  ///
  /// Anything that is not a key line is dropped, which is what lets the key
  /// file carry the comments the age tools write into it.
  List<String> get identityLines {
    final List<String> blocks = <String>[
      if (globals.platform.environment[kIdentityVariable] case final String inline) inline,
      if (keyFile.existsSync()) keyFile.readAsStringSync(),
    ];

    return <String>[
      for (final String block in blocks)
        for (final String line in block.split('\n'))
          if (line.trim().toUpperCase().startsWith(kIdentityPrefix)) line.trim().toUpperCase(),
    ];
  }

  /// The key pairs of [identityLines], each private key paired with its public one.
  Future<List<AgeKeyPair>> identities() async => <AgeKeyPair>[
    for (final String line in identityLines) await AgePlugin.convertIdentityToKeyPair(AgeIdentity.fromBech32(line)),
  ];

  /// Generates an X25519 key pair, appends it to [keyFile], and returns it.
  ///
  /// The file is appended to and never rewritten: a machine holds the key of
  /// every project it works on, and overwriting would lock the others out.
  Future<AgeKeyPair> createKey() async {
    final SimpleKeyPair pair = await X25519().newKeyPair();
    final AgeIdentity identity = AgeIdentity(kIdentityPrefix, Uint8List.fromList(await pair.extractPrivateKeyBytes()));
    final AgeRecipient recipient = AgeRecipient(
      kRecipientPrefix,
      Uint8List.fromList((await pair.extractPublicKey()).bytes),
    );

    await keyFile.parent.create(recursive: true);
    final String previous = keyFile.existsSync() ? keyFile.readAsStringSync() : '';
    await keyFile.writeAsString('${previous.trimRight()}\n$identity\n'.trimLeft());

    return AgeKeyPair(identity, recipient);
  }

  /// The secrets [file] holds, empty when the project has none yet.
  ///
  /// Throws a [ToolExit] when the file is there and no key opens it, naming
  /// both places a key is looked for.
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

  /// Writes [secrets] to [file], encrypted for [recipient].
  ///
  /// The whole set is rewritten each time, its names sorted. Age draws a fresh
  /// file key on every call, so the bytes differ even when nothing does: the
  /// diff of a commit says a secret moved, never which one.
  Future<void> write(Map<String, String> secrets, {required AgeRecipient recipient}) async {
    final String body = _render(secrets);
    final Uint8List payload = Uint8List.fromList(utf8.encode(body));

    final List<List<int>> sealed = await encrypt(Stream<List<int>>.value(payload), <AgeRecipient>[recipient]).toList();

    await file.writeAsBytes(sealed.flattened.toList());
  }

  /// The recipient [file] is to be written back for.
  ///
  /// It is the public half of whichever identity opens the file, found by
  /// trying each one, so a rewrite never changes who can read the result. A
  /// project without a `secrets.age` gets a new key instead.
  ///
  /// Throws a [ToolExit] when the file is there and no key opens it.
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

      secrets[entry.substring(0, separator)] = _unescape(entry.substring(separator + 1));
    }

    return secrets;
  }

  static String _render(Map<String, String> secrets) {
    final List<String> names = secrets.keys.toList()..sort();

    return <String>[for (final String name in names) '$name=${_escape(secrets[name]!)}'].join('\n');
  }

  /// [value], with a backslash and a newline turned into a two-character escape.
  ///
  /// The store is one `NAME=VALUE` line per secret, so a value carrying a literal newline would
  /// otherwise read back as a second, malformed line the next time this file is opened, silently
  /// truncating everything past it. Escaping the backslash first keeps `\n` in the escaped text
  /// unambiguous: [_unescape] undoes both in the order that reverses this one.
  static String _escape(String value) => value.replaceAll('\\', '\\\\').replaceAll('\n', '\\n');

  /// The inverse of [_escape].
  static String _unescape(String value) =>
      value.replaceAllMapped(RegExp(r'\\[\\n]'), (Match match) => match[0] == r'\n' ? '\n' : '\\');
}

/// One `NAME=VALUE` pair, as `secrets --set` is given it.
class SecretAssignment {
  /// Sets [name] to [value].
  const SecretAssignment(this.name, this.value);

  /// The assignment [raw] spells.
  ///
  /// Everything past the first `=` is the value, separators included, so a
  /// secret holding one needs no quoting.
  ///
  /// Throws a [UsageError] when [raw] carries no `=`, or when what precedes it
  /// does not match [secretName].
  static SecretAssignment parse(String raw) {
    final int separator = raw.indexOf('=');
    if (separator <= 0) {
      throwUsageError('--set expects NAME=VALUE, got "$raw".', command: 'secrets');
    }

    final String name = raw.substring(0, separator).trim();
    if (!secretName.hasMatch(name)) {
      throwUsageError(
        '"$name" is not a secret name. Use uppercase letters, digits and underscore, starting with a letter.',
        command: 'secrets',
      );
    }

    return SecretAssignment(name, raw.substring(separator + 1));
  }

  /// The secret's name.
  final String name;

  /// What it is being set to.
  final String value;
}
