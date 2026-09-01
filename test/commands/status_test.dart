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

import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/commands/status.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:test/test.dart';

/// The project every test in this file runs `status` inside.
const String kProjectDirectory = '/work/app';

/// Where the executables the fake machine carries are written.
const String kBinDirectory = '/usr/bin';

/// The root the templates are vendored under, standing in for an installed tool.
const String kToolRootDirectory = '/tools';

class _Machine {
  _Machine({String servicesOutput = ''})
    : processRunner = RecordingProcessRunner(outputs: <String, String>{'ps': servicesOutput}) {
    for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
      fs.file('$kBinDirectory/$executable').createSync(recursive: true);
    }

    fs.directory('$kProjectDirectory/lib').createSync(recursive: true);
    fs.file('$kProjectDirectory/config.yaml').writeAsStringSync('name: app\ndependencies: []\n');
    fs.file('$kProjectDirectory/configuration/main.yaml').createSync(recursive: true);
    fs.file('$kProjectDirectory/configuration/main.yaml').writeAsStringSync('targets:\n  local:\n    kind: dev\n');

    fs.file('$kToolRootDirectory/templates/deploy/configuration.yaml.tmpl').createSync(recursive: true);
    fs
        .file('$kToolRootDirectory/templates/deploy/configuration.yaml.tmpl')
        .writeAsStringSync(
          'requires:\n'
          '  - name: postgres\n'
          '    type: postgres\n'
          '  - name: redis\n'
          '    type: redis\n'
          '  - name: nats\n'
          '    type: nats\n'
          '  - name: rest\n'
          '    type: rest\n',
        );

    fs.currentDirectory = fs.directory(kProjectDirectory);
  }

  final MemoryFileSystem fs = MemoryFileSystem.test();
  final BufferLogger logger = BufferLogger();
  final RecordingProcessRunner processRunner;

  Future<int> run(List<String> args) => runner.run(
    args,
    () => <ScribeCommand>[StatusCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: () => processRunner,
      TemplatePathProvider: () => FixedTemplatePathProvider(fs.directory(kToolRootDirectory)),
      Platform: () => const FakePlatform(environment: <String, String>{'PATH': kBinDirectory, 'HOME': '/home/someone'}),
    },
  );
}

void main() {
  group('ServiceStatus.parse', () {
    test('splits the tab-separated line docker compose ps prints', () {
      final ServiceStatus status = ServiceStatus.parse('db\trunning\thealthy');

      expect(status.service, 'db');
      expect(status.state, 'running');
      expect(status.health, 'healthy');
    });

    test('a line missing a column leaves it empty rather than throwing', () {
      final ServiceStatus status = ServiceStatus.parse('db\trunning');

      expect(status.service, 'db');
      expect(status.state, 'running');
      expect(status.health, '');
    });

    test('toJson carries the three columns by name', () {
      const ServiceStatus status = ServiceStatus(service: 'db', state: 'running', health: 'healthy');

      expect(status.toJson(), <String, Object?>{'service': 'db', 'state': 'running', 'health': 'healthy'});
    });
  });

  group('status --machine', () {
    test('prints one line of JSON naming the target, the placements and the services', () async {
      final _Machine machine = _Machine(servicesOutput: 'db\trunning\thealthy\n');

      expect(await machine.run(<String>['status', '--target', 'local', '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['command'], 'status');
      expect(document['ok'], isTrue);
      expect(document['target'], <String, Object?>{'name': 'local', 'kind': 'dev', 'host': ''});

      expect(document['placements'], <Object?>[
        <String, Object?>{'resource': 'postgres', 'recipe': 'container'},
        <String, Object?>{'resource': 'redis', 'recipe': 'container'},
        <String, Object?>{'resource': 'nats', 'recipe': 'container'},
        <String, Object?>{'resource': 'rest', 'recipe': 'container'},
      ]);

      expect(document['services'], <Object?>[
        <String, Object?>{'service': 'db', 'state': 'running', 'health': 'healthy'},
      ]);
    });

    test('nothing running is still one line of JSON, with an empty services list', () async {
      final _Machine machine = _Machine();

      expect(await machine.run(<String>['status', '--target', 'local', '--machine']), 0);

      final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
      expect(document['services'], isEmpty);
      expect(machine.logger.statusText.trim().split('\n'), hasLength(1), reason: '--machine prints exactly one line');
    });

    test('a target that does not exist is refused the same way as without --machine', () async {
      final _Machine machine = _Machine();

      expect(await machine.run(<String>['status', '--target', 'ghost', '--machine']), 1);
      expect(machine.logger.errorText, contains('No target named "ghost"'));
    });
  });

  group('status without --machine', () {
    test('prints a report a person reads, target and placements first', () async {
      final _Machine machine = _Machine(servicesOutput: 'db\trunning\thealthy\n');

      expect(await machine.run(<String>['status', '--target', 'local']), 0);

      expect(machine.logger.statusText, contains('local  dev'));
      expect(machine.logger.statusText, contains('postgres'));
      expect(machine.logger.statusText, contains('db\trunning\thealthy'));
    });
  });
}
