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

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/base/watch.dart';
import 'package:scribe_tools/src/commands/daemon.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:test/test.dart';

/// The project every test in this file starts the daemon inside.
const String kProjectDirectory = '/work/app';

/// Where the executables the fake machine carries are written.
const String kBinDirectory = '/usr/bin';

/// The root the templates are vendored under, standing in for an installed tool.
const String kToolRootDirectory = '/tools';

class _Machine {
  _Machine() {
    for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
      fs.file('$kBinDirectory/$executable').createSync(recursive: true);
    }

    fs.directory('$kProjectDirectory/lib').createSync(recursive: true);
    fs
        .file('$kProjectDirectory/config.yaml')
        .writeAsStringSync('name: app\ndependencies: []\napi:\n  url: "https://app.example.com"\n');
    fs.file('$kProjectDirectory/configuration/main.yaml').createSync(recursive: true);
    fs.file('$kProjectDirectory/configuration/main.yaml').writeAsStringSync('targets:\n  local:\n    kind: dev\n');

    for (final String directory in <String>['sdk', 'engine', 'protocol']) {
      fs.directory('$kProjectDirectory/scribe/$directory').createSync(recursive: true);
    }
    fs.file('$kProjectDirectory/scribe/scribe.workspace.json').writeAsStringSync('{"version":"1.4.0","imports":{}}\n');

    fs.file('$kToolRootDirectory/templates/deploy/configuration.yaml.tmpl')
      ..createSync(recursive: true)
      ..writeAsStringSync('requires:\n  - name: postgres\n    type: postgres\n');

    fs.currentDirectory = fs.directory(kProjectDirectory);
  }

  final MemoryFileSystem fs = MemoryFileSystem.test();
  final BufferLogger logger = BufferLogger();
  final FakeWatcher watcher = FakeWatcher();
  final StreamController<List<int>> stdin = StreamController<List<int>>();

  /// Starts the daemon, reading [stdin] as it arrives.
  Future<int> start() => runner.run(
    <String>['daemon'],
    () => <ScribeCommand>[DaemonCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: () => FakeStdio(stdinStream: stdin.stream),
      ProcessRunner: RecordingProcessRunner.new,
      Watcher: () => watcher,
      TemplatePathProvider: () => FixedTemplatePathProvider(fs.directory(kToolRootDirectory)),
      Platform: () => const FakePlatform(environment: <String, String>{'PATH': kBinDirectory, 'HOME': '/home/someone'}),
    },
  );

  /// Writes [request] as one line, the shape a caller sends.
  void send(Map<String, Object?> request) => stdin.add(utf8.encode('${jsonEncode(request)}\n'));

  /// Writes every request of [requests], one line each, in order.
  void sendAll(List<Map<String, Object?>> requests) {
    for (final Map<String, Object?> request in requests) {
      send(request);
    }
  }

  /// Every line this daemon printed, each decoded from JSON.
  List<Map<String, Object?>> get lines => <Map<String, Object?>>[
    for (final String line in logger.statusText.trim().split('\n'))
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, Object?>,
  ];
}

void main() {
  late _Machine machine;

  setUp(() => machine = _Machine());

  test('opens with a daemon.ready event, and nothing else', () async {
    final Future<int> run = machine.start();

    machine.send(<String, Object?>{'id': 1, 'method': 'shutdown'});

    expect(await run, 0);
    expect(machine.lines.first, <String, Object?>{'event': 'daemon.ready'});
  });

  test('forge answers the same document forge --machine would, in a project', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'forge'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    final Map<String, Object?> answer = machine.lines[1];
    expect(answer['id'], 1);
    final Map<String, Object?> result = answer['result']! as Map<String, Object?>;
    expect(result['command'], 'forge');
    expect(result['kind'], 'project');
    expect(result['ok'], isTrue);
  });

  test('doctor answers doctorMachineReport', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'doctor'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    final Map<String, Object?> result = machine.lines[1]['result']! as Map<String, Object?>;
    expect(result['command'], 'doctor');
    expect(result['sections'], isNotEmpty);
  });

  test('status answers statusMachineReport for the target named', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{
        'id': 1,
        'method': 'status',
        'params': <String, Object?>{'target': 'local'},
      },
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    final Map<String, Object?> result = machine.lines[1]['result']! as Map<String, Object?>;
    expect(result['command'], 'status');
    expect((result['target']! as Map<String, Object?>)['name'], 'local');
  });

  test('status without a target is an error, not a crash', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'status'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    expect(machine.lines[1], <String, Object?>{'id': 1, 'error': 'status needs params.target as a string.'});
  });

  test('a target that is not a string is an error, not a crash that ends the daemon', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{
        'id': 1,
        'method': 'status',
        'params': <String, Object?>{'target': 123},
      },
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    expect(machine.lines[1], <String, Object?>{'id': 1, 'error': 'status needs params.target as a string.'});
    expect(machine.lines[2]['id'], 2);
  });

  test('params that is not a JSON object is an error, not a crash that ends the daemon', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'status', 'params': 'x'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    expect(machine.lines[1], <String, Object?>{'id': 1, 'error': '"params" must be a JSON object.'});
    expect(machine.lines[2]['id'], 2);
  });

  test('an unknown method is an error naming it', () async {
    final Future<int> run = machine.start();

    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'fly'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    expect(machine.lines[1], <String, Object?>{'id': 1, 'error': 'Unknown method "fly".'});
  });

  test('a line that is not JSON is an error with no id, and the daemon keeps reading', () async {
    final Future<int> run = machine.start();

    machine.stdin.add(utf8.encode('not json at all\n'));
    machine.sendAll(<Map<String, Object?>>[
      <String, Object?>{'id': 1, 'method': 'doctor'},
      <String, Object?>{'id': 2, 'method': 'shutdown'},
    ]);

    expect(await run, 0);
    expect(machine.lines[1]['id'], isNull);
    expect(machine.lines[1]['error'], contains('invalid JSON'));
    expect(machine.lines[2]['id'], 1);
  });

  test('the daemon ends when stdin closes, with no shutdown needed', () async {
    final Future<int> run = machine.start();

    machine.send(<String, Object?>{'id': 1, 'method': 'doctor'});
    await machine.stdin.close();

    expect(await run, 0);
    expect(machine.lines[1]['id'], 1);
  });

  group('watch', () {
    Future<void> untilWatching() async {
      while (machine.watcher.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('watch.start answers ok, then pushes forge.changed on every change', () async {
      final Future<int> run = machine.start();

      machine.send(<String, Object?>{'id': 1, 'method': 'watch.start'});
      await untilWatching();

      machine.watcher.change();
      await Future<void>.delayed(Duration.zero);

      machine.send(<String, Object?>{'id': 2, 'method': 'shutdown'});
      expect(await run, 0);

      expect(machine.lines[1], <String, Object?>{
        'id': 1,
        'result': <String, Object?>{'ok': true},
      });

      final Map<String, Object?> event = machine.lines[2];
      expect(event['event'], 'forge.changed');
      expect((event['result']! as Map<String, Object?>)['command'], 'forge');
    });

    test('watch.stop ends the watch, and a later change pushes nothing', () async {
      final Future<int> run = machine.start();

      machine.send(<String, Object?>{'id': 1, 'method': 'watch.start'});
      await untilWatching();

      machine.send(<String, Object?>{'id': 2, 'method': 'watch.stop'});
      await Future<void>.delayed(Duration.zero);

      machine.watcher.change();
      await Future<void>.delayed(Duration.zero);

      machine.send(<String, Object?>{'id': 3, 'method': 'shutdown'});
      expect(await run, 0);

      expect(machine.lines.any((Map<String, Object?> line) => line['event'] == 'forge.changed'), isFalse);
    });
  });
}
