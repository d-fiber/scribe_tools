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

import 'dart:io' as io;
import 'package:file/local.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/deploy/tofu.dart';
import 'package:test/test.dart';

/// The binary this machine has, which is what the live case is exercised with.
///
/// The CLI calls `tofu`. A machine that only carries Terraform reads the same
/// `.tf.json`, so the loop can be proven on either.
String? get _binary {
  for (final String candidate in <String>[tofuBinary, 'terraform']) {
    final io.ProcessResult found = io.Process.runSync('which', <String>[candidate]);
    if (found.exitCode == 0) return candidate;
  }

  return null;
}

const Map<String, Object?> _configuration = <String, Object?>{
  'terraform': <String, Object?>{
    'required_providers': <String, Object?>{
      'random': <String, Object?>{'source': 'hashicorp/random', 'version': '3.6.3'},
    },
  },
  'resource': <String, Object?>{
    'random_password': <String, Object?>{
      'this': <String, Object?>{'length': 24, 'special': false},
    },
  },
  'output': <String, Object?>{
    'host': <String, Object?>{'value': 'db.example.com'},
    'port': <String, Object?>{'value': 5432},
    'password': <String, Object?>{'value': r'${random_password.this.result}', 'sensitive': true},
  },
};

void main() {
  late io.Directory workspace;

  Future<T> inContext<T>(
    Future<T> Function() body, {
    Map<String, String> environment = const <String, String>{kTofuStateKeyVariable: 'a-passphrase-of-16-plus'},
  }) => AppContext.current.run<T>(
    overrides: <Type, Generator>{
      Logger: BufferLogger.new,
      Platform: () => FakePlatform(environment: environment),
    },
    body: body,
  );

  setUp(() => workspace = io.Directory.systemTemp.createTempSync('scribe-tofu-'));

  tearDown(() => workspace.deleteSync(recursive: true));

  test('a configuration is written as one JSON document and nothing else', () {
    Tofu(const LocalFileSystem().directory(workspace.path)).write(_configuration);

    expect(io.File('${workspace.path}/$tofuConfigurationName').readAsStringSync(), contains('"random_password"'));
    expect(workspace.listSync().map((io.FileSystemEntity e) => e.path.split('/').last), <String>[
      tofuConfigurationName,
    ]);
  });

  test('a workspace that was never applied answers no output', () async {
    final String? binary = _binary;
    if (binary == null) return;

    final Tofu tofu = Tofu(const LocalFileSystem().directory(workspace.path), binary: binary)..write(_configuration);

    await inContext(() async {
      expect(await tofu.init(), isTrue, reason: 'the provider has to come down before anything is read');
      expect(await tofu.outputs(), isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('what a recipe declares under output comes back as the values it made', () async {
    final String? binary = _binary;
    if (binary == null) return;

    final Tofu tofu = Tofu(const LocalFileSystem().directory(workspace.path), binary: binary)..write(_configuration);

    await inContext(() async {
      expect(await tofu.init(), isTrue);
      expect(await tofu.plan(), isNotNull);
      expect(await tofu.apply(), isTrue);

      final Map<String, String>? outputs = await tofu.outputs();

      expect(outputs?['host'], 'db.example.com');
      expect(outputs?['port'], '5432');
      expect(outputs?['password']?.length, 24, reason: 'a password a recipe made is what a consumer connects with');

      expect(await tofu.destroy(), isTrue);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('refuses to touch a workspace when no passphrase is set', () async {
    final String? binary = _binary;
    if (binary == null) return;

    final Tofu tofu = Tofu(const LocalFileSystem().directory(workspace.path), binary: binary)..write(_configuration);

    await inContext(() async {
      expect(await tofu.init(), isFalse);
      expect(await tofu.plan(), isNull);
    }, environment: const <String, String>{});
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a password a recipe made never sits in the state file in clear text', () async {
    final String? binary = _binary;
    if (binary == null) return;

    final Tofu tofu = Tofu(const LocalFileSystem().directory(workspace.path), binary: binary)..write(_configuration);

    await inContext(() async {
      expect(await tofu.init(), isTrue);
      expect(await tofu.apply(), isTrue);

      final Map<String, String>? outputs = await tofu.outputs();
      final String state = io.File('${workspace.path}/terraform.tfstate').readAsStringSync();

      expect(state, isNot(contains(outputs!['password'])), reason: 'the state has to be unreadable without the key');

      expect(await tofu.destroy(), isTrue);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
