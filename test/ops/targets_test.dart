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
    machine: host
  vps:
    machine: 4c/8t/4g
    cpu_cap: true
  big:
    machine: 8c/16t/24g
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
      final Hardware machine = Hardware.parse('4c/8t/4g', field: 'targets.vps.machine');

      expect(machine.cores, 4);
      expect(machine.threads, 8);
      expect(machine.memoryGb, 4);
    });

    test('is read whatever the spacing and the case', () {
      expect(Hardware.parse(' 8C / 16T / 24G ', field: 'x').cores, 8);
    });

    for (final String written in <String>['8c/16t', '8/16/24', 'huit coeurs', '8c/16t/24', '']) {
      test('"$written" is refused instead of read as something', () {
        expect(
          () => Hardware.parse(written, field: 'targets.vps.machine'),
          throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('8c/16t/32g'))),
        );
      });
    }

    for (final String written in <String>['0c/1t/1g', '8c/4t/8g', '8c/16t/0g']) {
      test('"$written" is refused as a machine that cannot exist', () {
        expect(() => Hardware.parse(written, field: 'x'), throwsA(isA<ToolExit>()));
      });
    }
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
