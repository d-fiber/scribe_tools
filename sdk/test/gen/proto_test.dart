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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final Directory _repositoryRoot = _locateRepositoryRoot();

Directory _locateRepositoryRoot() {
  Directory current = Directory.current;
  while (!File(p.join(current.path, 'scribe', 'protocol', 'VERSION')).existsSync()) {
    final Directory parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('no scribe/protocol/VERSION above ${Directory.current.path}');
    }
    current = parent;
  }
  return current;
}

List<String> _discoverProtoSources() => Directory(p.join(_repositoryRoot.path, 'scribe'))
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .map((File file) => file.path)
    .where((String path) => p.extension(path) == '.proto')
    .map((String path) => p.relative(path, from: _repositoryRoot.path))
    .toList()
  ..sort();

void main() {
  group('the protocol contract', () {
    test('every .proto lives in a protocol/ directory', () {
      final Iterable<String> misplaced = _discoverProtoSources()
          .where((String path) => p.basename(p.dirname(path)) != 'protocol');

      expect(
        misplaced,
        isEmpty,
        reason: 'a .proto outside protocol/ is invisible to the gen proto glob',
      );
    });

    test('the shared socket lives under scribe/protocol/', () {
      final List<String> shared = _discoverProtoSources()
          .where((String path) => p.dirname(path) == p.join('scribe', 'protocol'))
          .map(p.basename)
          .toList();

      expect(
        shared,
        containsAll(<String>['common.proto', 'invocation.proto', 'manifest.proto', 'logs.proto']),
      );
    });

    test('the whole contract compiles', () async {
      final List<String> sources = _discoverProtoSources();
      expect(sources, isNotEmpty);

      final ProcessResult result = await Process.run(
        'protoc',
        <String>['-I', _repositoryRoot.path, '--descriptor_set_out=/dev/null', ...sources],
        workingDirectory: _repositoryRoot.path,
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
    });

    test('the rest query carries no owner field', () {
      final File rest = File(
        p.join(_repositoryRoot.path, 'scribe', 'host', 'dependencies', 'database', 'rest', 'protocol', 'rest.proto'),
      );

      expect(rest.existsSync(), isTrue);
      expect(
        rest.readAsStringSync(),
        isNot(contains('owner')),
        reason: 'the owner filter is injected host-side, a worker must not be able to express it',
      );
    });

    test('no message shadows a dart:core type', () {
      const Set<String> shadowed = <String>{'Duration', 'List', 'Map', 'Set', 'Object', 'Error', 'Future', 'Stream'};

      final Iterable<String> offenders = _discoverProtoSources().expand((String path) {
        final File file = File(p.join(_repositoryRoot.path, path));
        return RegExp(r'^message (\w+) \{', multiLine: true)
            .allMatches(file.readAsStringSync())
            .map((RegExpMatch match) => match.group(1)!)
            .where(shadowed.contains)
            .map((String name) => '$path: $name');
      });

      expect(offenders, isEmpty, reason: 'a message shadowing dart:core breaks hand-written Dart in the worker SDK');
    });
  });
}
