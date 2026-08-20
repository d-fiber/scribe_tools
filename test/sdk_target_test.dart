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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/commands/create/project_scaffold.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/project_templates.dart';
import 'package:scribe_tools/src/sdk_target.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Future<T> withFileSystem<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs}, body: body);

void _write(String path, [String content = '']) => fs.file(path)
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(content);

void _framework() {
  fs.directory('/fw/host').createSync(recursive: true);
  fs.directory('/fw/protocol').createSync(recursive: true);

  _write('/fw/sdk/js/mod.ts', 'export {};');
  _write('/fw/sdk/js/deno.json', '{}');
  _write('/fw/sdk/js/src/server/server.ts', 'export {};');
  _write('/fw/sdk/js/src/http/client.ts', 'export {};');
  _write('/fw/sdk/js/gen/scribe_pb.ts', 'export {};');

  _write('/fw/sdk/dart/pubspec.yaml', 'name: scribe_sdk_dart');
  _write('/fw/sdk/dart/lib/gen/scribe.pb.dart', 'class A {}');
  _write('/fw/sdk/dart/lib/gen/failure.pb.dart', 'class B {}');

  fs.directory('/fw/sdk/go').createSync(recursive: true);
  _write('/fw/sdk/test/whatever.ts', 'export {};');

  _write('/fw/templates/project/common/gitignore', '.env\n.{{name}}/\n');
  _write('/fw/templates/project/common/config.yaml', 'name: "{{name}}"\nsdk: "{{sdk}}"\nurl: "https://{{host}}.example.com"\n');
  _write('/fw/templates/project/common/init/.gitkeep');
  _write('/fw/templates/project/common/lib/hostings/.gitkeep');
  _write('/fw/templates/project/js/lib/main.ts', 'import "@{{name}}/routes.ts";\n');
  _write('/fw/templates/project/js/lib/src/app/_middleware.ts', 'export class AppBrowsing {}\n');
  _write('/fw/templates/project/dart/lib/main.dart', 'void main() {}\n');
  _write('/fw/templates/project/dart/lib/src/app/_middleware.dart', 'class AppBrowsing {}\n');
  _write('/fw/templates/project/dart/pubspec.yaml', 'name: {{name}}\n');
  _write('/fw/templates/project/dart/gitignore', '.env\n.{{name}}/\n.dart_tool/\n');
}

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    _framework();
  });

  group('SdkCatalog', () {
    test('the choices are the directories of sdk/, not a list in the code', () async {
      await withFileSystem(() {
        final SdkCatalog catalog = SdkCatalog.discover(from: fs.directory('/fw'));

        expect(catalog.isKnown, isTrue);
        expect(catalog.targets.map((SdkTarget t) => t.name), <String>['dart', 'go', 'js', 'test']);
      });
    });

    test('a directory outside the maintained list is never offered', () async {
      await withFileSystem(() {
        final SdkCatalog catalog = SdkCatalog.discover(from: fs.directory('/fw'));

        expect(catalog.names, <String>['dart', 'ts']);
        expect(catalog.byName('ts'), same(catalog.byName('js')));
        expect(catalog.byName('test')!.isRecognised, isFalse);
        expect(catalog.ignored.map((SdkTarget t) => t.name), containsAll(<String>['go', 'test']));
      });
    });

    test('an empty directory is not a choice either', () async {
      await withFileSystem(() {
        final SdkTarget go = SdkCatalog.discover(from: fs.directory('/fw')).byName('go')!;

        expect(go.isRecognised, isTrue);
        expect(go.isEmpty, isTrue);
        expect(go.caveat, contains('empty directory'));
      });
    });

    test('an SDK whose files are all generated reads as stubs only', () async {
      await withFileSystem(() {
        final SdkCatalog catalog = SdkCatalog.discover(from: fs.directory('/fw'));

        final SdkTarget dart = catalog.byName('dart')!;
        expect(dart.isReady, isFalse);
        expect(dart.generatedFiles, 2);
        expect(dart.sourceFiles, 0);
        expect(dart.caveat, contains('generated'));

        final SdkTarget js = catalog.byName('js')!;
        expect(js.isReady, isTrue);
        expect(js.state, 'ready');
        expect(js.caveat, isNull);
      });
    });

    test('the extension it writes is read off the files, not guessed from the name', () async {
      await withFileSystem(() {
        final SdkCatalog catalog = SdkCatalog.discover(from: fs.directory('/fw'));

        expect(catalog.byName('js')!.sourceExtension, '.ts');
        expect(catalog.byName('dart')!.sourceExtension, '.dart');
      });
    });

    test('the checkout is found from below, and from a project that vendors it', () async {
      await withFileSystem(() {
        fs.directory('/fw/examples/notes').createSync(recursive: true);
        expect(SdkCatalog.findFrameworkRoot(fs.directory('/fw/examples/notes'))?.path, '/fw');

        fs.directory('/work/app/scribe/host').createSync(recursive: true);
        fs.directory('/work/app/scribe/protocol').createSync(recursive: true);
        fs.directory('/work/app/scribe/sdk').createSync(recursive: true);
        expect(SdkCatalog.findFrameworkRoot(fs.directory('/work/app'))?.path, '/work/app/scribe');
      });
    });

    test('no checkout anywhere is not a crash, it is an unknown catalog', () async {
      await withFileSystem(() {
        expect(SdkCatalog.discover(from: fs.directory('/elsewhere')).isKnown, isFalse);
      });
    });
  });

  group('ProjectTemplates', () {
    test('the layers merge, and the SDK wins over what every project shares', () async {
      await withFileSystem(() {
        final ProjectTemplates templates = ProjectTemplates.find(fs.directory('/fw'))!;

        final List<String> shared = templates.filesFor('js').map((TemplateFile f) => f.destination).toList();
        expect(shared, contains('config.yaml'));
        expect(shared, contains('lib/main.ts'));
        expect(shared, isNot(contains('lib/main.dart')));

        final TemplateFile ignore = templates
            .filesFor('dart')
            .firstWhere((TemplateFile f) => f.destination == '.gitignore');
        expect(ignore.source.path, '/fw/templates/project/dart/gitignore');
      });
    });

    test('a template named gitignore lands as .gitignore', () async {
      await withFileSystem(() {
        final ProjectTemplates templates = ProjectTemplates.find(fs.directory('/fw'))!;

        expect(templates.filesFor('js').map((TemplateFile f) => f.destination), contains('.gitignore'));
      });
    });

    test('the SDKs it can scaffold are the directories next to common/', () async {
      await withFileSystem(() {
        expect(ProjectTemplates.find(fs.directory('/fw'))!.sdkNames, <String>['dart', 'js']);
      });
    });

    test('a checkout without a templates directory is simply absent', () async {
      await withFileSystem(() {
        fs.directory('/bare/sdk').createSync(recursive: true);
        expect(ProjectTemplates.find(fs.directory('/bare')), isNull);
        expect(ProjectTemplates.find(null), isNull);
      });
    });
  });

  group('ProjectScaffold', () {
    Future<Project> scaffold(String sdkName) async {
      final SdkTarget target = SdkCatalog.discover(from: fs.directory('/fw')).byName(sdkName)!;
      final Directory root = fs.directory('/work/notes');

      final ProjectTemplates templates = ProjectTemplates.find(fs.directory('/fw'))!;

      await ProjectScaffold(root: root, name: 'notes', target: target, templates: templates).write();
      return Project.fromDirectory(root);
    }

    test('the entrypoint and the middleware carry the extension of the chosen SDK', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('dart');

        expect(project.directory.childFile('lib/main.dart').existsSync(), isTrue);
        expect(project.directory.childFile('lib/main.ts').existsSync(), isFalse);
        expect(project.directory.childFile('lib/src/app/_middleware.dart').existsSync(), isTrue);
      });
    });

    test('the chosen SDK is written down, so later commands read it back', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('dart');

        expect(project.config.readAsStringSync(), contains('sdk: "dart"'));
        expect(project.sdkName, 'dart');
        expect(project.entrypoint.path, '/work/notes/lib/main.dart');
        expect(project.missingEntries, isEmpty);
      });
    });

    test('a project without the field is the default SDK, and stays on main.ts', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('js');
        project.config.writeAsStringSync('name: "notes"\n');

        expect(project.sdkName, kDefaultSdkName);
        expect(project.entrypoint.path, '/work/notes/lib/main.ts');
      });
    });

    test('an underscore in the name never reaches a hostname', () async {
      await withFileSystem(() async {
        final SdkTarget target = SdkCatalog.discover(from: fs.directory('/fw')).byName('js')!;
        final ProjectTemplates templates = ProjectTemplates.find(fs.directory('/fw'))!;
        final Directory root = fs.directory('/work/my_app');

        await ProjectScaffold(root: root, name: 'my_app', target: target, templates: templates).write();

        final String config = root.childFile('config.yaml').readAsStringSync();
        expect(config, contains('name: "my_app"'));
        expect(config, contains('https://my-app.example.com'));
      });
    });

    test('a Dart project gets the pubspec a Dart project needs', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('dart');

        expect(project.directory.childFile('pubspec.yaml').readAsStringSync(), contains('name: notes'));
        expect(project.directory.childFile('.gitignore').readAsStringSync(), contains('.dart_tool/'));
      });
    });
  });
}
