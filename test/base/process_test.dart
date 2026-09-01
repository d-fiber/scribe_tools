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

import 'package:scribe_tools/src/base/process.dart';
import 'package:test/test.dart';

void main() {
  group('FakeProcessRunner', () {
    test('answers each scripted call with its own exit code and output, in order', () async {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'status', '--short'], stdout: ' M host/api.ts\n'),
        const FakeCommand(command: <String>['git', 'add', 'host/api.ts']),
        const FakeCommand(
          command: <String>['git', 'commit', '-m', 'checkpoint'],
          exitCode: 1,
          stderr: 'nothing to commit',
        ),
      ]);

      final String status = await processes.capture(<String>['git', 'status', '--short']);
      final int addCode = await processes.run(<String>['git', 'add', 'host/api.ts']);
      final ProcessOutcome commit = await processes.observe(<String>['git', 'commit', '-m', 'checkpoint']);

      expect(status, ' M host/api.ts\n');
      expect(addCode, 0);
      expect(commit.succeeded, isFalse);
      expect(commit.stderr, 'nothing to commit');
      expect(processes.commands, hasLength(3));

      processes.verifyDone();
    });

    test('fails the moment a call does not match what was expected next', () async {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'status']),
      ]);

      expect(() => processes.run(<String>['docker', 'compose', 'up']), throwsStateError);
    });

    test('fails when a call arrives in the wrong working directory', () async {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['deno', 'task', 'check'], workingDirectory: '/repo/engine'),
      ]);

      expect(
        () => processes.run(<String>['deno', 'task', 'check'], workingDirectory: '/repo/packages'),
        throwsStateError,
      );
    });

    test('fails when a call arrives after the script ran out', () async {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'status']),
      ]);

      await processes.run(<String>['git', 'status']);

      expect(() => processes.run(<String>['git', 'status']), throwsStateError);
    });

    test('verifyDone fails when a scripted call was never run', () async {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'status']),
        const FakeCommand(command: <String>['git', 'push']),
      ]);

      await processes.run(<String>['git', 'status']);

      expect(processes.verifyDone, throwsStateError);
    });

    test('observeSync and detach follow the same script as the async calls', () {
      final FakeProcessRunner processes = FakeProcessRunner(<FakeCommand>[
        const FakeCommand(command: <String>['git', 'rev-parse', 'HEAD'], stdout: 'abc123\n'),
        const FakeCommand(command: <String>['docker', 'compose', 'up', '-d']),
      ]);

      final ProcessOutcome revision = processes.observeSync(<String>['git', 'rev-parse', 'HEAD']);
      processes.detach(<String>['docker', 'compose', 'up', '-d']);

      expect(revision.stdout, 'abc123\n');
      processes.verifyDone();
    });
  });
}
