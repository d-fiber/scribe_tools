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
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The framework repository, checked out next to this one.
const String _repository = '../scribe';

const Hardware _machine = Hardware(cores: 8, threads: 16, memoryGb: 32);

final RegExp _placeholder = RegExp(r'\{\{[^}]*\}\}');

/// The root the templates are vendored under, standing in for an installed tool.
const String _toolRoot = '/tools';

/// Where the assembled documents land, since they no longer land in the project.
const String _stackHome = '/cache/scribe';

Future<T> _withContext<T>(FileSystem fs, Future<T> Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Logger: BufferLogger.new,
    Platform: () => const FakePlatform(environment: <String, String>{kStackHomeVariable: _stackHome}),
    TemplatePathProvider: () => FixedTemplatePathProvider(fs.directory(_toolRoot)),
  },
  body: body,
);

/// Copies what a render reads into [fs]: this package's templates and the framework's rest.
///
/// The templates and the package fragments are the input of every assertion
/// below, so the test reads the ones that ship rather than a fixture: a
/// fragment that stops matching its base has to fail here. The templates come
/// from this package because that is where an installed tool carries them, and
/// everything else from the framework checked out next door.
void _vendorFramework(FileSystem fs, String root) {
  for (final io.FileSystemEntity entity in io.Directory('templates/ops').listSync(recursive: true)) {
    if (entity is! io.File) continue;

    final String relative = p.relative(entity.path, from: 'templates/ops');
    _copy(fs, entity.path, p.join(_toolRoot, 'templates/ops', relative));
  }

  final io.Directory packages = io.Directory(p.join(_repository, 'packages'));
  if (!packages.existsSync()) return;

  for (final io.FileSystemEntity entity in packages.listSync(recursive: true)) {
    if (entity is! io.File) continue;

    final String relative = p.relative(entity.path, from: packages.path);
    final List<String> segments = p.split(relative);
    if (!segments.contains('ops') && !segments.contains('protocol')) continue;

    _copy(fs, entity.path, p.join(root, 'packages', relative));
  }
}

void _copy(FileSystem fs, String from, String to) {
  final File destination = fs.file(to);
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(io.File(from).readAsStringSync());
}

void main() {
  late MemoryFileSystem fs;

  /// A project mounting the packages named in [wanted].
  void project(List<String> wanted) {
    fs
        .file('/work/koko/config.yaml')
        .writeAsStringSync(
          'name: "koko"\n'
          'url: "https://koko.example.com"\n'
          'email: "dev@koko.example.com"\n'
          'api:\n'
          '  cors:\n'
          '    - "https://koko.example.com"\n'
          'dependencies:\n'
          '${wanted.map((String name) => '  - $name\n').join()}',
        );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    _vendorFramework(fs, '/work/koko/scribe');
    project(<String>['auth', 'audience']);
  });

  Future<ComposeDocuments> render({bool worker = false, String? target, String? stackRoot}) =>
      _withContext(fs, () async {
        fs.currentDirectory = '/work/koko';

        return ComposeRender(withWorker: worker, targetName: target, stackRoot: stackRoot).render(_machine);
      });

  /// Places [resource] on [className] for a target named `elsewhere`.
  void place(String resource, String className) =>
      (fs.file('/work/koko/configuration/main.yaml')..createSync(recursive: true)).writeAsStringSync(
        'targets:\n'
        '  elsewhere:\n'
        '    kind: machine\n'
        'deploy:\n'
        '  elsewhere:\n'
        '    $resource: $className\n',
      );

  Future<List<File>> renderFiles() async => (await render()).files;

  /// Writes a target block, so a render can be asked for something other than here.
  void target(String body) => (fs.file(
    '/work/koko/configuration/main.yaml',
  )..createSync(recursive: true)).writeAsStringSync('targets:\n  elsewhere:\n$body');

  group('a target that names a registry', () {
    test('names its images after the registry, and builds them from the project', () async {
      target('    kind: vps\n    registry: "ghcr.io/d-fiber"\n    tag: "v3"\n');
      final String compose = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(compose, contains('image: "ghcr.io/d-fiber/koko-api:v3"'));
      expect(compose, contains('image: "ghcr.io/d-fiber/koko-functions:v3"'));
      expect(compose, contains('context: "/work/koko"'));
    });

    test('mounts none of the project, because the image carries it', () async {
      target('    kind: vps\n    registry: "ghcr.io/d-fiber"\n');
      final String compose = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(compose, isNot(contains('/app/lib:ro')));
      expect(compose, isNot(contains('/app/scribe:ro')));
      expect(compose, contains('deno-cache:/deno-dir'));
    });

    test('puts the project inside the image it builds', () async {
      target('    kind: vps\n    registry: "ghcr.io/d-fiber"\n');
      await render(target: 'elsewhere');

      final String dockerfile = fs
          .directory('$_stackHome/stacks')
          .listSync()
          .whereType<Directory>()
          .single
          .childDirectory('services')
          .childDirectory('api')
          .childFile('Dockerfile')
          .readAsStringSync();

      expect(dockerfile, contains('COPY lib /app/lib'));
      expect(dockerfile, contains('COPY scribe /app/scribe'));
    });

    test('a target that names none keeps the mounts, and builds from the stack', () async {
      target('    kind: machine\n');
      final String compose = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(compose, contains('- "./lib:/app/lib:ro"'));
      expect(compose, contains('image: "koko-api:local"'));
      expect(compose, isNot(contains('context: "/work/koko"')));
    });
  });

  group('a stack rendered for a host that is not this one', () {
    const String there = '/home/deploy/.scribe_cache/stacks/abc123';

    test('names every path a container mounts on that host, not in this cache', () async {
      target('    kind: vps\n    registry: "ghcr.io/d-fiber"\n');
      final String compose = (await render(target: 'elsewhere', stackRoot: there)).files.first.readAsStringSync();

      expect(compose, contains('$there/env/host.env'));
      expect(compose, contains('$there/services/gateway'));
    });

    test('keeps the Dockerfile where the build happens, which is here', () async {
      target('    kind: vps\n    registry: "ghcr.io/d-fiber"\n');
      final String compose = (await render(target: 'elsewhere', stackRoot: there)).files.first.readAsStringSync();

      expect(compose, contains('dockerfile: "$_stackHome/stacks/'));
      expect(compose, contains('context: "/work/koko"'));
    });

    test('leaves every path in this cache when no host is named', () async {
      target('    kind: machine\n');
      final String compose = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(compose, contains('$_stackHome/stacks/'));
      expect(compose, isNot(contains('/home/deploy')));
    });
  });

  group('a resource a target placed somewhere else', () {
    test('takes its service out of every document it was declared in', () async {
      place('postgres', 'external');

      for (final File file in (await render(target: 'elsewhere')).files) {
        final Object? services = loadYaml(file.readAsStringSync()) is YamlMap
            ? (loadYaml(file.readAsStringSync()) as YamlMap)['services']
            : null;

        expect(
          services is YamlMap ? services.keys : const <Object?>[],
          isNot(contains('db')),
          reason: p.basename(file.path),
        );
      }
    });

    test('takes every dependency on that service out with it', () async {
      place('postgres', 'external');
      final String compose = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(compose, isNot(contains('      db:')));
      expect(compose, contains('      redis:'), reason: 'a datastore still in a container is still waited on');
    });

    test('binds the addresses of the stack to what the recipe of that class gives', () async {
      place('postgres', 'external');
      await render(target: 'elsewhere');

      expect(
        fs
            .directory('$_stackHome/stacks')
            .listSync()
            .whereType<Directory>()
            .single
            .childDirectory('env')
            .childFile('datastores.env')
            .readAsStringSync(),
        contains('REDIS_URL=redis://'),
      );
    });

    test('leaves the stack exactly as it was when nothing is placed anywhere else', () async {
      place('redis', 'container');
      final String placed = (await render(target: 'elsewhere')).files.first.readAsStringSync();

      expect(placed, contains('  db:'));
      expect(placed, contains('  redis:'));
      expect(placed, contains('      db:'));
    });
  });

  group('the compose render of a project', () {
    test('writes the four templates outside the project, in the stack cache', () async {
      final List<File> written = await renderFiles();

      expect(
        written.map((File file) => p.basename(file.path)),
        containsAll(composeTemplates),
        reason: 'these are the documents Compose is given in -f',
      );
      for (final File file in written) {
        expect(file.path, startsWith('$_stackHome/stacks/'), reason: 'the documents live outside the project');
      }
      expect(
        fs.directory('/work/koko/.koko/ops').existsSync(),
        isFalse,
        reason: 'nothing docker reads is written into the project',
      );
    });

    test('leaves no placeholder behind in anything it writes', () async {
      for (final File file in await renderFiles()) {
        expect(file.readAsStringSync(), isNot(matches(_placeholder)), reason: p.basename(file.path));
      }
    });

    test('everything it writes is parseable YAML', () async {
      for (final File file in await renderFiles()) {
        expect(() => loadYaml(file.readAsStringSync()), returnsNormally, reason: p.basename(file.path));
      }
    });

    test('it never writes into the framework, which stays fixed', () async {
      final List<File> written = await renderFiles();

      for (final File file in written) {
        expect(file.path, isNot(contains('/work/koko/scribe/')));
      }
    });

    test('a package the project did not ask for contributes nothing', () async {
      project(const <String>['storage']);

      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(services.keys, contains('storage'), reason: 'storage is in the selection');
      expect(services.keys, isNot(contains('opensearch')), reason: 'search is not');
      expect(services.keys, isNot(contains('realtime')), reason: 'realtime is not either');
    });

    test('gives a service the share the mounted ones leave it', () async {
      final List<File> written = await renderFiles();
      final File resources = written.firstWhere((File file) => p.basename(file.path) == 'resources.yaml');
      final YamlMap services = (loadYaml(resources.readAsStringSync()) as YamlMap)['services'] as YamlMap;
      final YamlMap limits = ((services['db'] as YamlMap)['deploy'] as YamlMap)['resources'] as YamlMap;

      expect(
        (limits['limits'] as YamlMap)['memory'],
        '11.44g',
        reason: 'db weighs 2122 against the 5371 this selection starts, not against the 6032 declared',
      );
    });

    test('switches on the profiles the mounted packages declare, and no others', () async {
      expect((await render()).profiles, isEmpty, reason: 'neither auth nor audience declares a profile');

      project(const <String>['search', 'realtime']);

      expect((await render()).profiles, <String>['realtime', 'search']);
    });

    test('starts the worker only when the command asks for it', () async {
      expect((await render()).profiles, isNot(contains('worker')));
      expect((await render(worker: true)).profiles, contains('worker'));
    });

    test('names the worker to the api only when the worker is started', () async {
      expect(_workerEndpointOf((await render()).files), isEmpty);
      expect(_workerEndpointOf((await render(worker: true)).files), workerEndpoint);
    });

    test('names a profile once, whatever number of services sit behind it', () async {
      project(const <String>['realtime']);

      expect((await render()).profiles, <String>['realtime'], reason: 'realtime and realtime-init both sit behind it');
    });

    test('a project that names no package gets the socle and foundation alone', () async {
      project(const <String>[]);

      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(services.keys, containsAll(<String>['db', 'redis', 'rest']), reason: 'foundation is not declinable');
      expect(services.keys, isNot(contains('storage')), reason: 'storage is a package like any other');
      expect(services.keys, isNot(contains('opensearch')));
    });

    test('a project that names every package still resolves', () async {
      project(const <String>['audience', 'auth', 'dynamic_links', 'realtime', 'remote_configs', 'search', 'storage']);

      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(services.keys, containsAll(<String>['opensearch', 'realtime', 'storage', 'imgproxy']));
      for (final File file in written) {
        expect(file.readAsStringSync(), isNot(matches(_placeholder)), reason: p.basename(file.path));
      }
    });

    test('a node asking for a key gets the variable that carries it', () async {
      fs
          .file('/work/koko/config.yaml')
          .writeAsStringSync(
            'name: "koko"\n'
            'url: "https://koko.example.com"\n'
            'email: "dev@koko.example.com"\n'
            'api:\n'
            '  cors:\n'
            '    - "https://koko.example.com"\n'
            '  nodes:\n'
            '    guarded:\n'
            '      api_key: true\n'
            '    open:\n'
            'dependencies:\n',
          );
      fs.directory('/work/koko/lib/guarded').createSync(recursive: true);
      fs.directory('/work/koko/lib/open').createSync(recursive: true);

      final List<File> written = await renderFiles();
      final String environment = written.first.parent.childDirectory('env').childFile('gateway.env').readAsStringSync();

      expect(
        environment,
        contains('GUARDED_KEYS=\${GUARDED_KEYS}'),
        reason: 'without the line the entry point drops the credential and the node refuses every key',
      );
      expect(environment, isNot(contains('OPEN_KEYS')), reason: 'a node that asks for no key gets no slot');
    });

    test('a replicated service carries no container name', () async {
      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(
        (services['rest'] as YamlMap)['container_name'],
        isNull,
        reason: 'Compose refuses the whole project when a replicated service fixes its name',
      );
    });
  });
}

/// The address the rendered `api` service is given to reach the worker on.
String _workerEndpointOf(List<File> rendered) {
  final File compose = rendered.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
  final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

  return ((services['api'] as YamlMap)['environment'] as YamlMap)['WORKER_ENDPOINT'] as String;
}
