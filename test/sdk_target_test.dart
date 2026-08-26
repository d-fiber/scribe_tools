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
import 'package:scribe_tools/src/commands/create/project_scaffold.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/project_templates.dart';
import 'package:scribe_tools/src/sdk_target.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Future<T> withFileSystem<T>(T Function() body, {String toolRoot = '/tools'}) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    TemplatePathProvider: () => FixedTemplatePathProvider(fs.directory(toolRoot)),
  },
  body: body,
);

void _write(String path, [String content = '']) => fs.file(path)
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(content);

void _framework() {
  fs.directory('/fw/engine').createSync(recursive: true);
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

  _write('/tools/templates/project/common/.gitignore.tmpl', '.env\n.{{name}}/\n');
  _write('/tools/templates/project/common/config.yaml.tmpl', 'name: "{{name}}"\nurl: "https://{{host}}.example.com"\n');
  _write('/tools/templates/project/common/init/.gitkeep.tmpl');
  _write('/tools/templates/project/common/lib/hostings/.gitkeep.tmpl');
  _write('/tools/templates/project/js/lib/main.ts.tmpl', 'import "@{{name}}/routes.ts";\n');
  _write('/tools/templates/project/js/lib/src/app/_middleware.ts.tmpl', 'export class AppBrowsing {}\n');
  _write('/tools/templates/project/dart/lib/main.dart.tmpl', 'void main() {}\n');
  _write('/tools/templates/project/dart/lib/src/app/_middleware.dart.tmpl', 'class AppBrowsing {}\n');
  _write('/tools/templates/project/dart/pubspec.yaml.tmpl', 'name: {{name}}\n');
  _write('/tools/templates/project/dart/.gitignore.tmpl', '.env\n.{{name}}/\n.dart_tool/\n');
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

        fs.directory('/work/app/scribe/engine').createSync(recursive: true);
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
        final ProjectTemplates templates = ProjectTemplates.find()!;

        final List<String> shared = templates.filesFor('js').map((TemplateFile f) => f.destination).toList();
        expect(shared, contains('config.yaml'));
        expect(shared, contains('lib/main.ts'));
        expect(shared, isNot(contains('lib/main.dart')));

        final TemplateFile ignore = templates
            .filesFor('dart')
            .firstWhere((TemplateFile f) => f.destination == '.gitignore');
        expect(ignore.source.path, '/tools/templates/project/dart/.gitignore.tmpl');
      });
    });

    test('the suffix is stripped, so .gitignore.tmpl lands as .gitignore', () async {
      await withFileSystem(() {
        final ProjectTemplates templates = ProjectTemplates.find()!;

        expect(templates.filesFor('js').map((TemplateFile f) => f.destination), contains('.gitignore'));
      });
    });

    test('a file without the suffix is not a template, and is not copied', () async {
      await withFileSystem(() {
        _write('/tools/templates/project/common/.DS_Store', 'noise');
        _write('/tools/templates/project/js/notes.md', 'not a template');

        final List<String> destinations = ProjectTemplates.find()!
            .filesFor('js')
            .map((TemplateFile f) => f.destination)
            .toList();

        expect(destinations, isNot(contains('.DS_Store')));
        expect(destinations, isNot(contains('notes.md')));
        expect(destinations, contains('lib/main.ts'));
      });
    });

    test('the SDKs it can scaffold are the directories next to common/', () async {
      await withFileSystem(() {
        expect(ProjectTemplates.find()!.sdkNames, <String>['dart', 'js']);
      });
    });

    test('a tool installed without its templates is simply absent', () async {
      await withFileSystem(toolRoot: '/bare', () {
        fs.directory('/bare').createSync(recursive: true);
        expect(ProjectTemplates.find(), isNull);
      });
    });
  });

  group('ProjectScaffold', () {
    Future<Project> scaffold(String sdkName) async {
      final SdkTarget target = SdkCatalog.discover(from: fs.directory('/fw')).byName(sdkName)!;
      final Directory root = fs.directory('/work/notes');

      final ProjectTemplates templates = ProjectTemplates.find()!;

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

    test('the SDK a later command reads back is the one the files were written in', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('dart');

        expect(project.config.readAsStringSync(), isNot(contains('sdk')));
        expect(project.sdkName, 'dart');
        expect(project.missingEntries, isEmpty);
      });
    });

    test('a lib holding no source at all is the default SDK', () async {
      await withFileSystem(() async {
        final Project project = await scaffold('dart');
        project.lib.deleteSync(recursive: true);
        project.lib.createSync(recursive: true);

        expect(project.sdkName, kDefaultSdkName);
      });
    });

    test('an underscore in the name never reaches a hostname', () async {
      await withFileSystem(() async {
        final SdkTarget target = SdkCatalog.discover(from: fs.directory('/fw')).byName('js')!;
        final ProjectTemplates templates = ProjectTemplates.find()!;
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
