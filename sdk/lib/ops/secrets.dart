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
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/commands/openssl.dart';
import '../core/commands/python3.dart';
import '../core/exception.dart';
import '../core/paths/infra_files.dart';
import '../core/process.dart';

class X25519KeyPair {
  X25519KeyPair(this.privateKeyHex, this.publicKeyHex);

  final String privateKeyHex;
  final String publicKeyHex;
}

class Secrets {
  static final Random _random = Random.secure();

  static const String _alnumChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (int _) => _random.nextInt(256)));

  static String _b64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static String _hex(List<int> bytes) =>
      bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String _last32BytesHex(List<int> bytes) =>
      _hex(bytes.sublist(bytes.length - 32));

  static String randBase64(int n) =>
      base64.encode(_randomBytes(n)).replaceAll('=', '');

  static String randAlnum(int n) {
    return List.generate(
      n,
      (int _) => _alnumChars[_random.nextInt(_alnumChars.length)],
    ).join();
  }

  static String hookSecret() => 'v1,whsec_${base64.encode(_randomBytes(32))}';

  static String generateJwt(
    String role,
    String secret, {
    required String issuer,
  }) {
    final String header = _b64UrlNoPad(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String payload = _b64UrlNoPad(
      utf8.encode(
        jsonEncode({
          'role': role,
          'iss': issuer,
          'iat': now,
          'exp': now + 10 * 365 * 24 * 3600,
        }),
      ),
    );
    final String signingInput = '$header.$payload';
    final Digest sig = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(signingInput));
    return '$signingInput.${_b64UrlNoPad(sig.bytes)}';
  }

  static Future<String> bcryptHash(String password) async {
    final Python3 command = Python3()
      ..evalCode(
        'import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(10)).decode())',
      )
      ..scriptArg(password);
    final ProcessResult result = await capture(
      command.executable,
      command.args,
    );
    if (result.exitCode != 0) {
      throw CliException('bcrypt hashing failed: ${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  static Future<ProcessResult> _opensslPkeyDer(
    String pemPath, {
    required bool public,
  }) {
    final OpenSSL command = OpenSSL()
      ..pkey()
      ..inFile(pemPath);
    if (public) command.pubout();
    command.outform('DER');
    return Process.run(command.executable, command.args, stdoutEncoding: null);
  }

  static Future<X25519KeyPair> x25519Keypair() async {
    final File tmp = InfraFiles.tree.tmpX25519Pem;

    final OpenSSL genCommand = OpenSSL()
      ..genpkey()
      ..algorithm('X25519')
      ..out(tmp.path);
    final ProcessResult gen = await capture(
      genCommand.executable,
      genCommand.args,
    );
    if (gen.exitCode != 0) {
      throw CliException('openssl genpkey failed: ${gen.stderr}');
    }

    try {
      final ProcessResult privResult = await _opensslPkeyDer(
        tmp.path,
        public: false,
      );
      final ProcessResult pubResult = await _opensslPkeyDer(
        tmp.path,
        public: true,
      );

      if (privResult.exitCode != 0 || pubResult.exitCode != 0) {
        throw CliException(
          'openssl pkey failed: ${privResult.stderr}${pubResult.stderr}',
        );
      }

      final List<int> privBytes = privResult.stdout as List<int>;
      final List<int> pubBytes = pubResult.stdout as List<int>;

      final String priv = _last32BytesHex(privBytes);
      final String pub = _last32BytesHex(pubBytes);
      return X25519KeyPair(priv, pub);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }
}
