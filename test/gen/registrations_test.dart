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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/config/registrations.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Future<T> _run<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs, Logger: BufferLogger.new}, body: body);

/// Writes a module at [path] under [root], with a `register.ts` when asked.
void _module(String root, String path, {bool registers = true}) {
  final Directory directory = fs.directory('/work/notes/scribe/host/$root/$path')..createSync(recursive: true);
  directory.childDirectory('protocol').createSync();
  if (registers) directory.childFile('register.ts').writeAsStringSync('');
}

/// Writes the project's `config.yaml`, mounting [wanted].
void _project(List<String> wanted) {
  fs
      .file('/work/notes/config.yaml')
      .writeAsStringSync(
        'name: "notes"\n'
        'dependencies:\n'
        '${wanted.map((String path) => '  - $path\n').join()}',
      );
}

String _generated() => fs.file('/work/notes/.notes/sdk/js/registrations.ts').readAsStringSync();

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
    fs.currentDirectory = '/work/notes';
    _project(const <String>[]);
  });

  test('a mounted module with a register.ts is imported for its effect', () async {
    _module('dependencies', 'security/rbac');
    _project(const <String>['security/rbac']);

    await _run(generateRegistrations);

    expect(_generated(), contains('import "@scribe/host/dependencies/security/rbac/register.ts";'));
  });

  test('a module in the packages submodule renders under its own root', () async {
    _module('packages', 'security/auth');
    _project(const <String>['security/auth']);

    await _run(generateRegistrations);

    expect(_generated(), contains('import "@scribe/host/packages/security/auth/register.ts";'));
  });

  test('a module without a register.ts contributes no import', () async {
    _module('dependencies', 'features/searcher', registers: false);
    _project(const <String>['features/searcher']);

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
    _project(const <String>['security/auth', 'database/storage']);

    await _run(generateRegistrations);

    final List<String> lines = _generated().split('\n').where((String line) => line.startsWith('import')).toList();

    expect(lines, <String>[
      'import "@scribe/host/dependencies/database/storage/register.ts";',
      'import "@scribe/host/packages/security/auth/register.ts";',
    ]);
  });
}
