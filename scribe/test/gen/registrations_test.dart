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
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/commands/gen/code/generators/config/registrations.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Future<T> _run<T>(T Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{FileSystem: () => fs, Logger: () => BufferLogger()},
  body: body,
);

/// Writes a module at [path] under [root], with a `register.ts` when asked.
void _module(String root, String path, {bool registers = true}) {
  final Directory directory = fs.directory('/work/notes/scribe/host/$root/$path')
    ..createSync(recursive: true);
  directory.childFile('scribe.yaml').writeAsStringSync('name: ${path.split('/').last}\n');
  if (registers) directory.childFile('register.ts').writeAsStringSync('');
}

String _generated() =>
    fs.file('/work/notes/.notes/sdk/js/registrations.ts').readAsStringSync();

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
    fs.file('/work/notes/config.yaml').writeAsStringSync('name: "notes"\n');
    fs.currentDirectory = '/work/notes';
  });

  test('a mounted module with a register.ts is imported for its effect', () async {
    _module('dependencies', 'security/rbac');

    await _run(generateRegistrations);

    expect(_generated(), contains('import "@scribe/host/dependencies/security/rbac/register.ts";'));
  });

  test('a module in the packages submodule renders under its own root', () async {
    _module('packages', 'security/auth');

    await _run(generateRegistrations);

    expect(_generated(), contains('import "@scribe/host/packages/security/auth/register.ts";'));
  });

  test('a module without a register.ts contributes no import', () async {
    _module('dependencies', 'features/searcher', registers: false);

    await _run(generateRegistrations);

    expect(_generated(), isNot(contains('searcher')));
  });

  test('a project that mounts nothing still gets the file the host imports', () async {
    await _run(generateRegistrations);

    expect(_generated(), isNot(contains('import')));
  });

  test('the imports are sorted, so the file does not churn between runs', () async {
    _module('packages', 'security/auth');
    _module('dependencies', 'database/storage');

    await _run(generateRegistrations);

    final List<String> lines = _generated()
        .split('\n')
        .where((String line) => line.startsWith('import'))
        .toList();

    expect(lines, <String>[
      'import "@scribe/host/dependencies/database/storage/register.ts";',
      'import "@scribe/host/packages/security/auth/register.ts";',
    ]);
  });
}
