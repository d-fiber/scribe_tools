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

import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:test/test.dart';

import 'package:file/file.dart';

Future<T> withFileSystem<T>(FileSystem fs, T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs}, body: body);

void main() {
  late MemoryFileSystem fs;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes/lib/src/app').createSync(recursive: true);
    fs.file('/work/notes/config.yaml').writeAsStringSync('name: "notes"\n');
  });

  test('a project is found from its own root', () async {
    await withFileSystem(fs, () {
      fs.currentDirectory = '/work/notes';

      expect(Project.current.name, 'notes');
    });
  });

  test('a command run below the root is refused, and told where the root is', () async {
    await withFileSystem(fs, () {
      fs.currentDirectory = '/work/notes/lib/src/app';

      expect(Project.currentOrNull, isNull);
      expect(Project.findAbove(fs.currentDirectory)?.directory.path, '/work/notes');
      expect(
        () => Project.current,
        throwsA(
          isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains('/work/notes')),
        ),
      );
    });
  });

  test('the root is recognised by config.yaml alone', () async {
    await withFileSystem(fs, () {
      expect(Project.isProjectRoot(fs.directory('/work/notes')), isTrue);
      expect(Project.isProjectRoot(fs.directory('/work')), isFalse);
    });
  });

  test('no project above the current directory fails with a way out', () async {
    await withFileSystem(fs, () {
      fs.currentDirectory = '/work';

      expect(Project.currentOrNull, isNull);
      expect(
        () => Project.current,
        throwsA(
          isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains('scribe create')),
        ),
      );
    });
  });

  test('the generated directory and the import alias carry the project name', () async {
    await withFileSystem(fs, () {
      fs.currentDirectory = '/work/notes';
      final Project project = Project.current;

      expect(project.generatedDirectoryName, '.notes');
      expect(project.generatedAlias, '@notes/');
      expect(project.generated.sdk.routes.path, '/work/notes/.notes/sdk/js/routes.ts');
      expect(project.generated.docs.surface('admin').path, '/work/notes/.notes/docs/admin.yaml');
    });
  });

  test('the three entries and the sdk checkout sit where create puts them', () async {
    await withFileSystem(fs, () {
      fs.currentDirectory = '/work/notes';
      final Project project = Project.current;

      expect(project.entrypoint.path, '/work/notes/lib/main.ts');
      expect(project.sources.path, '/work/notes/lib/src');
      expect(project.dependencies.path, '/work/notes/lib/dependencies');
      expect(project.hostings.path, '/work/notes/lib/hostings');
      expect(project.init.path, '/work/notes/init');
      expect(project.migrations.path, '/work/notes/migrations');
      expect(project.tests.path, '/work/notes/tests');
      expect(project.sdk.hostDbInit.path, '/work/notes/scribe/host/core/db/init');
    });
  });
}
