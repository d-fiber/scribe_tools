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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/create.dart';
import 'package:scribe_tools/src/commands/gen.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';
import 'package:test/test.dart';

ScribeCommandRunner runnerWithCommands() {
  final ScribeCommandRunner runner = ScribeCommandRunner(toolVersion: 'test');
  for (final ScribeCommand command in <ScribeCommand>[CreateCommand(), GenCommand()]) {
    runner.addCommand(command);
  }

  return runner;
}

void main() {
  group('the usage a refusal is printed with', () {
    test('a top-level command is found by name', () {
      expect(runnerWithCommands().usageOf('create'), contains('Usage: scribe create <name>'));
    });

    test('a subcommand is found by its leaf name', () {
      expect(runnerWithCommands().usageOf('code'), contains('scribe gen code'));
    });

    test('a name nothing carries, and no name at all, answer nothing', () {
      expect(runnerWithCommands().usageOf('nope'), isNull);
      expect(runnerWithCommands().usageOf(null), isNull);
    });
  });

  group('the name a command is refused under', () {
    test('a top-level command is named as it is typed', () {
      final ScribeCommandRunner runner = runnerWithCommands();

      expect((runner.commands['create']! as ScribeCommand).invocationName, 'scribe create');
    });

    test('a subcommand carries its parents', () {
      final ScribeCommandRunner runner = runnerWithCommands();
      final ScribeCommand gen = runner.commands['gen']! as ScribeCommand;

      expect((gen.subcommands['code']! as ScribeCommand).invocationName, 'scribe gen code');
    });

    test('a command outside a runner still answers with the tool it belongs to', () {
      expect(CreateCommand().invocationName, '$kToolName create');
    });
  });
}
