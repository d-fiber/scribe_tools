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
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/commands/clean.dart';
import 'package:scribe_tools/src/commands/forge.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:test/test.dart';

import 'package_source.dart';

/// The project every project-side test in this file runs `clean` inside.
const String kProjectDirectory = '/work/app';

/// Where the executables the fake project machine carries are written.
const String kBinDirectory = '/usr/bin';

class _ProjectMachine {
  _ProjectMachine() {
    for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
      fs.file('$kBinDirectory/$executable').createSync(recursive: true);
    }

    fs.directory('$kProjectDirectory/lib').createSync(recursive: true);
    fs
        .file('$kProjectDirectory/config.yaml')
        .writeAsStringSync(
          'name: app\ndependencies: []\napi:\n  url: "https://app.example.com"\n  cors:\n    - "https://app.example.com"\n',
        );

    for (final String directory in <String>['sdk', 'engine', 'protocol']) {
      fs.directory('$kProjectDirectory/scribe/$directory').createSync(recursive: true);
    }
    fs.file('$kProjectDirectory/scribe/deno.json').writeAsStringSync('{"version":"1.4.0","imports":{}}\n');

    fs.currentDirectory = fs.directory(kProjectDirectory);
  }

  final MemoryFileSystem fs = MemoryFileSystem.test();
  final BufferLogger logger = BufferLogger();

  Future<int> run(List<String> args) => runner.run(
    args,
    () => <ScribeCommand>[CleanCommand(), ForgeCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: RecordingProcessRunner.new,
      Platform: () => const FakePlatform(environment: <String, String>{'PATH': kBinDirectory, 'HOME': '/home/someone'}),
    },
  );
}

void main() {
  group('clean in a project', () {
    late _ProjectMachine machine;

    setUp(() => machine = _ProjectMachine());

    test('removes the derived directory forge wrote', () async {
      await machine.run(<String>['forge']);
      expect(machine.fs.directory('$kProjectDirectory/.app').existsSync(), isTrue);

      expect(await machine.run(<String>['clean']), 0);

      expect(machine.fs.directory('$kProjectDirectory/.app').existsSync(), isFalse);
    });

    test('leaves the committed lock alone', () async {
      await machine.run(<String>['forge']);

      await machine.run(<String>['clean']);

      expect(machine.fs.file('$kProjectDirectory/scribe.lock').existsSync(), isTrue);
    });

    test('--dry-run lists what would go, and removes nothing', () async {
      await machine.run(<String>['forge']);

      expect(await machine.run(<String>['clean', '--dry-run']), 0);

      expect(machine.fs.directory('$kProjectDirectory/.app').existsSync(), isTrue);
      expect(machine.logger.statusText, contains('would remove'));
    });

    test('a project with nothing derived yet says so', () async {
      expect(await machine.run(<String>['clean']), 0);

      expect(machine.logger.statusText, contains('Nothing to clean'));
    });
  });

  group('clean in a package', () {
    late PackageHarness machine;

    setUp(() => machine = PackageHarness());

    Future<String> package(String name) async {
      await machine.run(<String>['create', name, '--package']);
      final String at = '$kWorkDirectory/$name';
      machine.fs.currentDirectory = machine.fs.directory(at);
      return at;
    }

    test('removes the resolution forge wrote, and keeps the committed package.lock', () async {
      final String at = await package('notifications');
      await machine.run(<String>['forge']);
      expect(machine.fs.directory('$at/$kResolutionDirectory').existsSync(), isTrue);

      expect(await machine.run(<String>['clean']), 0);

      expect(machine.fs.directory('$at/$kResolutionDirectory').existsSync(), isFalse);
      expect(machine.fs.file('$at/$kPackageLockFile').existsSync(), isTrue);
    });
  });
}
