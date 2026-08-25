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

/// Writes a package called [name] in the checkout, with a `register.ts` when asked.
void _package(String name, {bool registers = true}) {
  final Directory directory = fs.directory('/work/notes/scribe/packages/$name')..createSync(recursive: true);
  directory.childDirectory('protocol').createSync();
  if (registers) directory.childFile('register.ts').writeAsStringSync('');
}

/// Writes the project's `config.yaml`, mounting [wanted].
void _project(List<String> wanted) {
  fs
      .file('/work/notes/config.yaml')
      .writeAsStringSync(
        'name: "notes"\n'
        'packages:\n'
        '${wanted.map((String name) => '  - $name\n').join()}',
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

  test('a mounted package carries its lifecycle into the file the host reads', () async {
    _package('audience');
    _project(const <String>['audience']);

    await _run(generateRegistrations);

    expect(_generated(), contains('import { scribe as _audience } from "@scribe/audience";'));
    expect(_generated(), contains('{ name: "audience", steps: _audience },'));
  });

  test('the specifier is the package door, so it holds no path into the checkout', () async {
    _package('auth');
    _project(const <String>['auth']);

    await _run(generateRegistrations);

    expect(_generated(), contains('from "@scribe/auth";'));
    expect(_generated(), isNot(contains('packages/')));
  });

  test('a package that runs at no moment is listed all the same', () async {
    _package('audience', registers: false);
    _project(const <String>['audience']);

    await _run(generateRegistrations);

    expect(
      _generated(),
      contains('{ name: "audience", steps: _audience },'),
      reason: 'whether it runs is read off its door, not guessed from the tree',
    );
  });

  test('a project that mounts nothing still gets the list the host reads', () async {
    await _run(generateRegistrations);

    expect(_generated(), contains('export const mounted = ['));
    expect(_generated(), isNot(contains('import')));
  });

  test('the order is the one the manifest wrote, since it decides who fills a port first', () async {
    _package('storage');
    _package('auth');
    _project(const <String>['storage', 'auth']);

    await _run(generateRegistrations);

    final List<String> named = _generated()
        .split('\n')
        .where((String line) => line.trimLeft().startsWith('{ name:'))
        .toList();

    expect(named, <String>['  { name: "storage", steps: _storage },', '  { name: "auth", steps: _auth },']);
  });

  test('a manifest that still spells the key dependencies is read all the same', () async {
    _package('audience');
    fs.file('/work/notes/config.yaml').writeAsStringSync('name: "notes"\ndependencies:\n  - audience\n');

    await _run(generateRegistrations);

    expect(_generated(), contains('from "@scribe/audience";'));
  });
}
