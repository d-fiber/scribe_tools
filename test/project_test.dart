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
