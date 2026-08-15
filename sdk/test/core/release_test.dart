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

import 'package:sdk/core/release/release_check.dart';
import 'package:sdk/core/release/release_source.dart';
import 'package:sdk/core/release/version.dart';
import 'package:test/test.dart';

class _Fixed implements ReleaseSource {
  _Fixed(this.value);

  final Version? value;
  int reads = 0;

  @override
  Future<Version?> read() async {
    reads++;
    return value;
  }
}

class _Broken implements ReleaseSource {
  @override
  Future<Version?> read() async => throw const SocketException('offline');
}

void main() {
  late Directory workspace;
  late File cache;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('scribe-release-');
    cache = File('${workspace.path}/release.json');
  });

  tearDown(() => workspace.deleteSync(recursive: true));

  group('a version', () {
    test('parses and prints back the same thing', () {
      expect(Version.parse(' 2.0.0\n').toString(), '2.0.0');
    });

    test('refuses anything that is not three numbers', () {
      for (final String raw in <String>['2.0', 'v2.0.0', '', '2.0.0-rc1']) {
        expect(Version.tryParse(raw), isNull, reason: raw);
      }
    });

    test('orders by major, then minor, then patch', () {
      expect(Version.parse('1.2.3') < Version.parse('1.10.0'), isTrue);
      expect(Version.parse('2.0.0') > Version.parse('1.99.99'), isTrue);
      expect(Version.parse('1.0.0'), Version.parse('1.0.0'));
    });
  });

  group('the release check', () {
    test('reports an update when the published branch is ahead', () async {
      final ReleaseStatus status = await ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: _Fixed(Version.parse('1.1.0')),
        cacheFile: cache,
      ).status();

      expect(status.state, ReleaseState.updateAvailable);
      expect(status.needsUpdate, isTrue);
      expect(status.describe(), contains('1.1.0 is available'));
    });

    test('reports up to date when both agree', () async {
      final ReleaseStatus status = await ReleaseCheck(
        local: _Fixed(Version.parse('1.1.0')),
        remote: _Fixed(Version.parse('1.1.0')),
        cacheFile: cache,
      ).status();

      expect(status.state, ReleaseState.upToDate);
      expect(status.needsUpdate, isFalse);
    });

    test('reports ahead when working on an unreleased version', () async {
      final ReleaseStatus status = await ReleaseCheck(
        local: _Fixed(Version.parse('2.0.0')),
        remote: _Fixed(Version.parse('1.1.0')),
        cacheFile: cache,
      ).status();

      expect(status.state, ReleaseState.ahead);
    });

    test('stays quiet and never throws when the network is down', () async {
      final ReleaseStatus status = await ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: _Broken(),
        cacheFile: cache,
      ).status();

      expect(status.state, ReleaseState.unknown);
      expect(status.local, Version.parse('1.0.0'));
    });

    test('does not hit the network twice inside the cache window', () async {
      final _Fixed remote = _Fixed(Version.parse('1.1.0'));
      ReleaseCheck build() => ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: remote,
        cacheFile: cache,
      );

      await build().status();
      await build().status();

      expect(remote.reads, 1);
    });

    test('hits the network again once the cache has expired', () async {
      final _Fixed remote = _Fixed(Version.parse('1.1.0'));
      DateTime clock = DateTime(2026, 8, 16, 9);

      ReleaseCheck build() => ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: remote,
        cacheFile: cache,
        ttl: const Duration(hours: 12),
        now: () => clock,
      );

      await build().status();
      clock = clock.add(const Duration(hours: 13));
      await build().status();

      expect(remote.reads, 2);
    });

    test('ignores a corrupt cache instead of failing', () async {
      cache.writeAsStringSync('this is not json');
      final _Fixed remote = _Fixed(Version.parse('1.1.0'));

      final ReleaseStatus status = await ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: remote,
        cacheFile: cache,
      ).status();

      expect(status.state, ReleaseState.updateAvailable);
      expect(jsonDecode(cache.readAsStringSync())['version'], '1.1.0');
    });

    test('force skips the cache', () async {
      final _Fixed remote = _Fixed(Version.parse('1.1.0'));
      ReleaseCheck build() => ReleaseCheck(
        local: _Fixed(Version.parse('1.0.0')),
        remote: remote,
        cacheFile: cache,
      );

      await build().status();
      await build().status(force: true);

      expect(remote.reads, 2);
    });
  });

  group('the local and remote sources', () {
    test('the local source reads the VERSION file of the SDK', () async {
      final File version = File('${workspace.path}/VERSION')..writeAsStringSync('1.4.2\n');

      expect(await LocalRelease(version).read(), Version.parse('1.4.2'));
    });

    test('the local source is silent when there is no VERSION file', () async {
      expect(await LocalRelease(File('${workspace.path}/absent')).read(), isNull);
    });

    test('the remote source points at main of the published repository', () {
      expect(
        const RemoteRelease().url.toString(),
        'https://raw.githubusercontent.com/d-fiber/scribe/main/VERSION',
      );
    });

    test('the remote source reads what it is handed', () async {
      final RemoteRelease remote = RemoteRelease(fetch: (Uri url) async => '3.2.1\n');

      expect(await remote.read(), Version.parse('3.2.1'));
    });
  });
}
