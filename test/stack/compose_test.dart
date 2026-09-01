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

import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/stack/compose.dart';
import 'package:scribe_tools/src/stack/stack_manifest.dart';
import 'package:test/test.dart';

const StackManifest _manifest = StackManifest(
  projectDirectory: '/work/koko',
  projectName: 'koko',
  files: <String>['/work/koko/.scribe/stack/api.yaml'],
  profiles: <String>['worker'],
);

void main() {
  late RecordingProcessRunner processes;

  Future<T> run<T>(Future<T> Function() body) =>
      AppContext.current.run<T>(overrides: <Type, Generator>{ProcessRunner: () => processes}, body: body);

  setUp(() => processes = RecordingProcessRunner());

  test('restart names docker compose restart, the stack and every service given', () async {
    await run(() => const Compose(_manifest).restart(<String>['api', 'worker']));

    expect(processes.commands.single, <String>[
      'docker',
      'compose',
      '--project-directory',
      '/work/koko',
      '-p',
      'koko',
      '-f',
      '/work/koko/.scribe/stack/api.yaml',
      '--profile',
      'worker',
      'restart',
      'api',
      'worker',
    ]);
  });

  test('restart with a single service names only that one', () async {
    await run(() => const Compose(_manifest).restart(<String>['api']));

    expect(processes.commands.single.skip(processes.commands.single.length - 2), <String>['restart', 'api']);
  });

  test('up starts detached and removes orphans', () async {
    await run(() => const Compose(_manifest).up());

    expect(processes.commands.single.skip(processes.commands.single.length - 3), <String>[
      'up',
      '-d',
      '--remove-orphans',
    ]);
  });
}
