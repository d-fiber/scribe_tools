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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:test/test.dart';

Future<T> _run<T>(ProcessRunner processes, Future<T> Function() body) => AppContext.current.run<T>(
  overrides: <Type, Generator>{FileSystem: MemoryFileSystem.test, ProcessRunner: () => processes},
  body: body,
);

void main() {
  test('reads threads and memory from the Darwin sysctl keys when nproc and /proc/meminfo are both absent', () {
    _run(
      RecordingProcessRunner(outputs: const <String, String>{'hw.logicalcpu': '8', 'hw.memsize': '17179869184'}),
      () async {
        final Hardware hardware = await Hardware.detect();

        expect(hardware.threads, 8);
        expect(hardware.memoryGb, 16);
      },
    );
  });

  test('reads cores straight from hw.physicalcpu without ever reaching for lscpu', () {
    _run(RecordingProcessRunner(outputs: const <String, String>{'hw.physicalcpu': '4'}), () async {
      final Hardware hardware = await Hardware.detect();

      expect(hardware.cores, 4);
    });
  });

  test('counts the unique core,socket pairs lscpu -p=Core,Socket prints when hw.physicalcpu is absent', () {
    _run(
      RecordingProcessRunner(outputs: const <String, String>{'lscpu': '# comment line, ignored\n0,0\n1,0\n0,0\n1,0'}),
      () async {
        final Hardware hardware = await Hardware.detect();

        expect(hardware.cores, 2);
      },
    );
  });
}
