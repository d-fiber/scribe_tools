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
import 'package:scribe_tools/src/commands/forge.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/package/lock.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:test/test.dart';

/// The project every test in this file runs `forge` inside.
const String kProjectDirectory = '/work/app';

/// Where the executables this fake machine carries are written.
const String kBinDirectory = '/usr/bin';

class _Machine {
  _Machine() {
    for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
      fs.file('$kBinDirectory/$executable').createSync(recursive: true);
    }

    fs.directory('$kProjectDirectory/lib').createSync(recursive: true);
    fs
        .file('$kProjectDirectory/config.yaml')
        .writeAsStringSync(
          'name: app\ndependencies:\n  - auth\napi:\n  url: "https://app.example.com"\n  cors:\n    - "https://app.example.com"\n',
        );

    for (final String directory in <String>['sdk', 'engine', 'protocol']) {
      fs.directory('$kProjectDirectory/scribe/$directory').createSync(recursive: true);
    }
    fs
        .file('$kProjectDirectory/scribe/deno.json')
        .writeAsStringSync(
          '{"version":"1.4.0","imports":{'
          '"@scribe/foundation":"./packages/foundation/lib/foundation.ts",'
          '"@scribe/auth":"./packages/auth/lib/auth.ts"'
          '}}\n',
        );

    _package('foundation', '1.0.0', 'dependencies:\n');
    _package('auth', '1.1.0', 'dependencies:\n  foundation: ^1.0.0\n');

    fs.currentDirectory = fs.directory(kProjectDirectory);
  }

  final MemoryFileSystem fs = MemoryFileSystem.test();
  final BufferLogger logger = BufferLogger();

  void _package(String name, String version, String dependencies) {
    fs.directory('$kProjectDirectory/scribe/packages/$name/protocol').createSync(recursive: true);
    fs
        .file('$kProjectDirectory/scribe/packages/$name/package.yaml')
        .writeAsStringSync('name: $name\nversion: $version\n\nenvironment:\n  scribe: "^1.0.0"\n\n$dependencies');
  }

  Future<int> run(List<String> args) => runner.run(
    args,
    () => <ScribeCommand>[ForgeCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: RecordingProcessRunner.new,
      Platform: () => const FakePlatform(environment: <String, String>{'PATH': kBinDirectory, 'HOME': '/home/someone'}),
    },
  );

  PackageLock lock() => PackageLock.parse(fs.file('$kProjectDirectory/scribe.lock').readAsStringSync(), 'scribe.lock');
}

void main() {
  late _Machine machine;

  setUp(() => machine = _Machine());

  test('forge writes a lock naming the framework version the project vendors', () async {
    expect(await machine.run(<String>['forge']), 0);

    expect(machine.lock().scribe, '1.4.0');
  });

  test('forge locks a mounted package and what it depends on, at the versions it found', () async {
    await machine.run(<String>['forge']);

    expect(machine.lock().byName('auth')?.version, '1.1.0');
    expect(machine.lock().byName('foundation')?.version, '1.0.0');
  });

  test('a dependency of a mounted package is locked even when config.yaml never named it', () async {
    await machine.run(<String>['forge']);

    expect(
      machine.lock().byName('foundation'),
      isNotNull,
      reason:
          'auth depends on foundation, and foundation is mounted regardless, but the lock should say why it is there',
    );
  });

  test('forge says the lock was written', () async {
    await machine.run(<String>['forge']);

    expect(machine.logger.statusText, contains('scribe.lock'));
    expect(machine.logger.statusText, contains('1.4.0'));
  });

  test('--dry-run writes no lock', () async {
    await machine.run(<String>['forge', '--dry-run']);

    expect(machine.fs.file('$kProjectDirectory/scribe.lock').existsSync(), isFalse);
  });

  test('forge writes what dependencies: decides, not only the lock', () async {
    await machine.run(<String>['forge']);

    final File importMap = machine.fs.file('$kProjectDirectory/.app/sdk/js/scribe.json');
    final File registrations = machine.fs.file('$kProjectDirectory/.app/sdk/js/registrations.ts');
    final File declarations = machine.fs.file('$kProjectDirectory/.app/sdk/js/declarations.ts');

    expect(importMap.existsSync(), isTrue, reason: 'gen code used to write this, forge now does');
    expect(importMap.readAsStringSync(), contains('@scribe/auth'));
    expect(registrations.readAsStringSync(), contains('from "@scribe/auth"'));
    expect(declarations.existsSync(), isTrue);
  });

  test('--machine prints one line of JSON naming the entries, the lock and the version', () async {
    expect(await machine.run(<String>['forge', '--machine']), 0);

    final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
    expect(document['command'], 'forge');
    expect(document['kind'], 'project');
    expect(document['ok'], isTrue);
    expect(document['dryRun'], isFalse);
    expect(document['scribeVersion'], '1.4.0');
    expect(document['lockFile'], '$kProjectDirectory/scribe.lock');
    expect(document['entries'], <Object?>[
      <String, Object?>{'name': mainConfigurationName, 'verdict': 'written'},
    ]);
    expect(machine.logger.statusText.trim().split('\n'), hasLength(1), reason: '--machine prints exactly one line');
  });

  test('--dry-run --machine reports what is missing, and neither writes nor names a lock', () async {
    expect(await machine.run(<String>['forge', '--dry-run', '--machine']), 0);

    final Map<String, Object?> document = jsonDecode(machine.logger.statusText.trim()) as Map<String, Object?>;
    expect(document['dryRun'], isTrue);
    expect(document['lockFile'], isNull);
    expect(document['scribeVersion'], isNull);
    expect(machine.fs.file('$kProjectDirectory/scribe.lock').existsSync(), isFalse);
  });

  test('a package a project mounts that accepts a version this checkout does not carry is refused', () async {
    machine.fs
        .file('$kProjectDirectory/scribe/packages/auth/package.yaml')
        .writeAsStringSync(
          'name: auth\nversion: 1.1.0\n\nenvironment:\n  scribe: "^1.0.0"\n\ndependencies:\n  foundation: ^2.0.0\n',
        );

    expect(await machine.run(<String>['forge']), 1);
    expect(machine.logger.errorText, contains('foundation'));
    expect(machine.logger.errorText, contains('^2.0.0'));
  });
}
