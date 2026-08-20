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

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The machine a stack is sized for.
///
/// [detect] reads the machine this command is running on, which is only the
/// right answer when the command runs on the machine the stack will run on.
/// Rendering from a workstation for a server is what `deploy.machine` in
/// `config.yaml` is for.
class Hardware {
  /// Holds a machine of [cores] cores, [threads] threads and [memoryGb] gibibytes.
  const Hardware({required this.cores, required this.threads, required this.memoryGb});

  /// Physical cores, which is what parallelism settings are derived from.
  final int cores;

  /// Hardware threads, which is what connection counts are derived from.
  final int threads;

  /// Total memory in gibibytes, rounded, and 0 when nothing could read it.
  final int memoryGb;

  @override
  String toString() => '$cores c / $threads t, $memoryGb Go';

  /// The machine this command is running on.
  static Future<Hardware> detect() async {
    final int threads = await _threads();

    return Hardware(cores: await _cores(threads), threads: threads, memoryGb: await _memoryGb());
  }

  static Future<int> _threads() async {
    final int? linux = await _intFrom(<String>['nproc', '--all']);
    if (linux != null) return linux;

    final int? darwin = await _intFrom(<String>['sysctl', '-n', 'hw.logicalcpu']);
    if (darwin != null) return darwin;

    return io.Platform.numberOfProcessors;
  }

  static Future<int> _cores(int threads) async {
    final int? darwin = await _intFrom(<String>['sysctl', '-n', 'hw.physicalcpu']);
    if (darwin != null) return darwin;

    final String? lscpu = await _capture(<String>['lscpu', '-p=Core,Socket']);
    if (lscpu != null) {
      final Set<String> unique = <String>{
        for (final String raw in lscpu.split('\n'))
          if (raw.trim().isNotEmpty && !raw.startsWith('#')) raw.trim(),
      };
      if (unique.isNotEmpty) return unique.length;
    }

    return threads;
  }

  static Future<int> _memoryGb() async {
    final File meminfo = globals.fs.file('/proc/meminfo');
    if (meminfo.existsSync()) {
      final RegExpMatch? match = RegExp(r'MemTotal:\s+(\d+) kB').firstMatch(meminfo.readAsStringSync());
      if (match != null) return (int.parse(match.group(1)!) / (1024 * 1024)).round();
    }

    final int? darwin = await _intFrom(<String>['sysctl', '-n', 'hw.memsize']);
    if (darwin != null) return (darwin / (1024 * 1024 * 1024)).round();

    return 0;
  }

  static Future<int?> _intFrom(List<String> command) async {
    final String? output = await _capture(command);

    return output == null ? null : int.tryParse(output.trim());
  }

  /// The output of [command], or null when it is absent or fails.
  ///
  /// Every probe here is expected to be missing on some platform, `nproc` on
  /// macOS and `sysctl` on Linux, so a failure is a normal answer rather than an
  /// error worth reporting.
  static Future<String?> _capture(List<String> command) async {
    try {
      return await globals.processRunner.capture(command);
    } on Object {
      return null;
    }
  }
}
