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

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/ops/capacity.dart';
import 'package:scribe/src/ops/hardware.dart';
import 'package:scribe/src/ops/sizing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The framework repository, two levels above this package.
const String _repository = '../../scribe';

const Hardware _machine = Hardware(cores: 8, threads: 16, memoryGb: 32);

final RegExp _placeholder = RegExp(r'\{\{\w+\}\}');

Future<T> _withContext<T>(FileSystem fs, Future<T> Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{FileSystem: () => fs, Logger: () => BufferLogger()},
  body: body,
);

/// Copies the parts of the real framework a render reads into [fs].
///
/// The templates and the module fragments are the input of every assertion
/// below, so the test reads the ones that ship rather than a fixture: a
/// fragment that stops matching its base has to fail here.
void _vendorFramework(FileSystem fs, String root) {
  for (final String name in <String>[...composeTemplates, capacityFileName]) {
    _copy(fs, p.join(_repository, 'ops/docker', name), p.join(root, 'ops/docker', name));
  }

  final io.Directory modules = io.Directory(p.join(_repository, 'host/dependencies'));
  for (final io.FileSystemEntity entity in modules.listSync(recursive: true)) {
    if (entity is! io.File) continue;

    final String relative = p.relative(entity.path, from: modules.path);
    final bool wanted = p.basename(relative) == 'scribe.yaml' || p.split(relative).contains('ops');
    if (!wanted) continue;

    _copy(fs, entity.path, p.join(root, 'host/dependencies', relative));
  }
}

void _copy(FileSystem fs, String from, String to) {
  final File destination = fs.file(to);
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(io.File(from).readAsStringSync());
}

void main() {
  late MemoryFileSystem fs;

  /// A project asking for [wanted], an empty list meaning every module.
  void project(List<String> wanted) {
    fs.file('/work/koko/config.yaml').writeAsStringSync(
      'name: "koko"\n'
      'url: "https://koko.example.com"\n'
      'email: "dev@koko.example.com"\n'
      'dependencies:\n'
      '${wanted.map((String path) => '  - $path\n').join()}',
    );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    _vendorFramework(fs, '/work/koko/scribe');
    project(<String>['security/auth', 'security/rbac']);
  });

  Future<ComposeDocuments> render() => _withContext(fs, () async {
    fs.currentDirectory = '/work/koko';

    return ComposeRender().render(_machine);
  });

  Future<List<File>> renderFiles() async => (await render()).files;

  group('the compose render of a project', () {
    test('writes the four templates under the generated ops directory', () async {
      final List<File> written = await renderFiles();

      expect(
        written.map((File file) => p.basename(file.path)),
        containsAll(composeTemplates),
        reason: 'these are the documents Compose is given in -f',
      );
      for (final File file in written) {
        expect(p.dirname(file.path), '/work/koko/.koko/ops');
      }
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

    test('a module the project did not ask for contributes nothing', () async {
      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(services.keys, contains('auth'), reason: 'security/auth is in the selection');
      expect(services.keys, isNot(contains('opensearch')), reason: 'features/searcher is not');
      expect(services.keys, isNot(contains('realtime')), reason: 'database/realtime is not either');
    });

    test('gives a service the share the mounted ones leave it', () async {
      final List<File> written = await renderFiles();
      final File resources = written.firstWhere((File file) => p.basename(file.path) == 'resources.yaml');
      final YamlMap services = (loadYaml(resources.readAsStringSync()) as YamlMap)['services'] as YamlMap;
      final YamlMap limits =
          ((services['db'] as YamlMap)['deploy'] as YamlMap)['resources'] as YamlMap;

      // 2122 against the 5989 this selection starts, not against the 9966 the
      // repository declares. The fixed scale gave 5.45g here. Neither studio nor
      // the worker counts: this selection switches on no profile at all.
      expect((limits['limits'] as YamlMap)['memory'], '9.07g');
    });

    // The threshold this replaces switched `search` on from 8 GiB of RAM and
    // nothing else, so a project that asked for `features/searcher` on a small
    // machine got an opensearch container Compose never started, and a project
    // that did not ask for it got one it never wanted.
    test('switches on the profiles the mounted modules declare, and no others', () async {
      expect((await render()).profiles, isEmpty, reason: 'neither auth nor rbac declares a profile');

      project(const <String>['features/searcher', 'database/realtime']);

      expect((await render()).profiles, <String>['realtime', 'search']);
    });

    // No module declares the worker profile: the host loads the project in its
    // own process unless the project says otherwise, and a worker container
    // nobody talks to would be a second Deno taking a tenth of the machine.
    test('starts the worker only when config.yaml asks for it', () async {
      expect((await render()).profiles, isNot(contains('worker')));

      fs.file('/work/koko/config.yaml').writeAsStringSync(
        '${fs.file('/work/koko/config.yaml').readAsStringSync()}worker: true\n',
      );

      expect((await render()).profiles, contains('worker'));
    });

    test('names a shared profile once, whichever module brought it', () async {
      project(const <String>['security/vpn', 'features/observability']);

      expect((await render()).profiles, <String>['ops']);
    });

    // Every module's fragments are merged at once, so every setting the
    // templates ask for has to come out of the capacity that was loaded. A
    // service whose settings nobody produces fails here as an unresolved
    // placeholder, which is the failure mode the per-service table introduced.
    test('a project that names no module mounts them all and still resolves', () async {
      project(const <String>[]);

      final List<File> written = await renderFiles();
      final File compose = written.firstWhere((File file) => p.basename(file.path) == 'docker-compose.yaml');
      final YamlMap services = (loadYaml(compose.readAsStringSync()) as YamlMap)['services'] as YamlMap;

      expect(services.keys, containsAll(<String>['opensearch', 'realtime', 'gorse', 'analytics']));
      for (final File file in written) {
        expect(file.readAsStringSync(), isNot(matches(_placeholder)), reason: p.basename(file.path));
      }
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
