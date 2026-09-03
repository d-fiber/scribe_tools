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
import 'package:scribe_tools/src/commands/completion.dart';
import 'package:scribe_tools/src/commands/doctor.dart';
import 'package:scribe_tools/src/commands/gen.dart';
import 'package:scribe_tools/src/commands/status.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:test/test.dart';

class _Machine {
  _Machine() {
    fs.directory('/work').createSync(recursive: true);
    fs.currentDirectory = '/work';
  }

  final MemoryFileSystem fs = MemoryFileSystem.test();
  final BufferLogger logger = BufferLogger();

  Future<int> run(List<String> args, {String shell = '/bin/bash'}) => runner.run(
    args,
    () => <ScribeCommand>[CompletionCommand(), DoctorCommand(), GenCommand(), StatusCommand()],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: RecordingProcessRunner.new,
      Platform: () => FakePlatform(environment: <String, String>{'SHELL': shell, 'HOME': '/home/someone'}),
    },
  );
}

void main() {
  late _Machine machine;

  setUp(() => machine = _Machine());

  test('runs with no project at the root, since it reads no manifest', () async {
    expect(await machine.run(<String>['completion', 'bash']), 0);
  });

  group('bash', () {
    test('prints one function completing the top level and a nested command', () async {
      expect(await machine.run(<String>['completion', 'bash']), 0);

      final String script = machine.logger.statusText;
      expect(script, startsWith('#!/usr/bin/env bash\n'));
      expect(script, contains('_scribe_complete() {'));
      expect(script, contains('complete -F _scribe_complete scribe'));
      expect(
        script,
        contains('"") COMPREPLY=( \$(compgen -W "completion doctor gen status --color'),
        reason: 'the auto-registered help command is hidden, and does not sit among the words offered here',
      );
      expect(script, contains('"gen") COMPREPLY=( \$(compgen -W "code docs hosting routes --color'));
      expect(script, contains('"gen code")'));
    });

    test('a value-taking flag is skipped so its value is not mistaken for a subcommand', () async {
      expect(await machine.run(<String>['completion', 'bash']), 0);

      final String script = machine.logger.statusText;
      expect(
        script,
        contains('--target|-t) skip=1 ;;'),
        reason: '"status --target prod" must not rebuild "path" as "status prod"',
      );
      expect(script, contains(r'if [ "$skip" = 1 ]; then'));
    });
  });

  group('zsh', () {
    test('carries the same function behind a bashcompinit shim', () async {
      expect(await machine.run(<String>['completion', 'zsh']), 0);

      final String script = machine.logger.statusText;
      expect(script, startsWith('#!/usr/bin/env zsh\n'));
      expect(script, contains('autoload -U +X bashcompinit && bashcompinit'));
      expect(script, contains('_scribe_complete() {'));
    });
  });

  group('fish', () {
    test('one -n condition per command word, chained with and', () async {
      expect(await machine.run(<String>['completion', 'fish']), 0);

      final String script = machine.logger.statusText;
      expect(script, contains("complete -c scribe -n '__fish_use_subcommand' -a 'completion doctor gen status'"));
      expect(script, contains("complete -c scribe -n '__fish_seen_subcommand_from gen' -a 'code docs hosting routes'"));
      expect(
        script,
        contains(
          "complete -c scribe -n '__fish_seen_subcommand_from gen; and __fish_seen_subcommand_from code' -l color",
        ),
      );
    });
  });

  test('with no shell named, the one SHELL points at is used', () async {
    expect(await machine.run(<String>['completion'], shell: '/bin/zsh'), 0);

    expect(machine.logger.statusText, startsWith('#!/usr/bin/env zsh\n'));
  });

  test('an unknown shell is refused, naming the three that are known', () async {
    expect(await machine.run(<String>['completion', 'powershell']), 64);
    expect(machine.logger.errorText, contains('bash, zsh, fish'));
  });

  test('nothing but the script itself reaches standard output', () async {
    expect(await machine.run(<String>['completion', 'bash']), 0);

    expect(machine.logger.statusText.trim(), endsWith('complete -F _scribe_complete scribe'));
  });
}
