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
