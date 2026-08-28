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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:test/test.dart';

const String _manifest = '''
name: koko
api:
  url: "https://koko.example.com"
  cors:
    - "https://koko.example.com"
targets:
  local:
    kind: dev
    machine: host
  vps:
    kind: machine
    machine:
      cores: 4
      threads: 8
      memory: 4g
    cpu_cap: true
  big:
    machine:
      cores: 8
      threads: 16
      memory: 24g
''';

late MemoryFileSystem fs;

Future<T> withEnvironment<T>(Map<String, String> environment, T Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{
    FileSystem: () => fs,
    Platform: () => FakePlatform(environment: environment),
  },
  body: body,
);

ScribeManifest manifestOf(String body) {
  final File file = fs.file('/work/config.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync(body);

  return ScribeManifest.load(file);
}

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  group('a machine written as a target', () {
    test('is read as cores, threads and gibibytes', () {
      final Hardware machine = Hardware.parse(<Object?, Object?>{
        'cores': 4,
        'threads': 8,
        'memory': '4g',
      }, field: 'targets.vps.machine');

      expect(machine.cores, 4);
      expect(machine.threads, 8);
      expect(machine.memoryGb, 4);
    });

    test('takes memory with the gibibyte suffix or without it', () {
      final Map<Object?, Object?> bare = <Object?, Object?>{'cores': 8, 'threads': 16, 'memory': 24};

      expect(Hardware.parse(bare, field: 'x').memoryGb, 24);
      expect(Hardware.parse(<Object?, Object?>{...bare, 'memory': ' 24G '}, field: 'x').memoryGb, 24);
    });

    for (final MapEntry<String, Map<Object?, Object?>> written in <String, Map<Object?, Object?>>{
      'a core count that is not a number': <Object?, Object?>{'cores': 'huit', 'threads': 16, 'memory': '24g'},
      'a memory that names no gibibytes': <Object?, Object?>{'cores': 8, 'threads': 16, 'memory': 'beaucoup'},
      'nothing at all': <Object?, Object?>{},
    }.entries) {
      test('${written.key} is refused instead of read as something', () {
        expect(
          () => Hardware.parse(written.value, field: 'targets.vps.machine'),
          throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('targets.vps.machine'))),
        );
      });
    }

    for (final MapEntry<String, Map<Object?, Object?>> written in <String, Map<Object?, Object?>>{
      'no core': <Object?, Object?>{'cores': 0, 'threads': 1, 'memory': '1g'},
      'fewer threads than cores': <Object?, Object?>{'cores': 8, 'threads': 4, 'memory': '8g'},
      'no memory': <Object?, Object?>{'cores': 8, 'threads': 16, 'memory': '0g'},
    }.entries) {
      test('${written.key} is refused as a machine that cannot exist', () {
        expect(() => Hardware.parse(written.value, field: 'x'), throwsA(isA<ToolExit>()));
      });
    }
  });

  group('the kind a target declares', () {
    test('is what it wrote', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).kindOf('local'), TargetKind.dev);
        expect(manifestOf(_manifest).kindOf('vps'), TargetKind.machine);
      });
    });

    test('is a machine when the target names none, which is what a target used to mean', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).kindOf('big'), TargetKind.machine);
      });
    });

    test('is refused when it names something that is not a kind', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(
          () => manifestOf(_manifest.replaceFirst('kind: dev', 'kind: laptop')).kindOf('local'),
          throwsA(
            isA<ToolExit>().having(
              (ToolExit e) => e.message,
              'message',
              allOf(
                contains('laptop'),
                contains(TargetKind.values.map((TargetKind kind) => kind.name).join(', ')),
              ),
            ),
          ),
        );
      });
    });

    test('names the platform a paas target deploys onto, and nothing for the others', () async {
      await withEnvironment(const <String, String>{}, () {
        final ScribeManifest manifest = manifestOf(
          _manifest.replaceFirst('  big:', '  cloud:\n    kind: paas\n    platform: fly\n  big:'),
        );

        expect(manifest.kindOf('cloud'), TargetKind.paas);
        expect(manifest.platformOf('cloud'), 'fly');
        expect(manifest.platformOf('vps'), '');
      });
    });
  });

  group('the targets a manifest declares', () {
    test('are read in the order they were written', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).targetNames, <String>['local', 'vps', 'big']);
      });
    });

    test('a target naming the host takes the machine this runs on', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).machineOf('local'), isNull);
      });
    });

    test('a target naming a machine answers with it', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).machineOf('vps')?.memoryGb, 4);
        expect(manifestOf(_manifest).machineOf('big')?.threads, 16);
      });
    });

    test('an unknown target is refused with the list of those that exist', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(
          () => manifestOf(_manifest).machineOf('vsp'),
          throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('local, vps, big'))),
        );
      });
    });

    test('a project declaring none is told so rather than sent to a list', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(
          () => manifestOf('name: koko\n').machineOf('vps'),
          throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('declares none at all'))),
        );
      });
    });

    test('the cpu ceiling is off unless a target asks for it', () async {
      await withEnvironment(const <String, String>{}, () {
        expect(manifestOf(_manifest).cpuCapOf('vps'), isTrue);
        expect(manifestOf(_manifest).cpuCapOf('big'), isFalse);
        expect(manifestOf(_manifest).cpuCapOf('local'), isFalse);
      });
    });
  });
}
