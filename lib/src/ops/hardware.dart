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
import 'package:scribe_tools/src/base/common.dart';
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

  /// The machine a target declares, read from the three keys it names it with.
  ///
  /// A deployment writes it when the command does not run on the machine the
  /// stack will. Detection answers for the machine at hand and cannot answer for
  /// another one: a render made on a workstation for a server would otherwise
  /// size the server like the workstation, which is the defect this exists to
  /// close.
  ///
  /// ```yaml
  /// machine:
  ///   cores: 4
  ///   threads: 8
  ///   memory: 8g
  /// ```
  ///
  /// Throws a `ToolExit` naming the key at fault, because a machine read wrong is
  /// worse than a machine not declared: the render succeeds and every limit is
  /// off by the ratio between the two machines.
  static Hardware parse(Map<Object?, Object?> declared, {required String field}) {
    final int cores = _whole(declared['cores'], field: '$field.cores');
    final int threads = _whole(declared['threads'], field: '$field.threads');
    final int memoryGb = _gibibytes(declared['memory'], field: '$field.memory');

    if (cores < 1 || threads < cores || memoryGb < 1) {
      throwToolExit(
        '$field names a machine that cannot exist: $cores cores, $threads threads, $memoryGb Go.\n'
        'A machine has at least one core, at least as many threads as cores, and at least one gibibyte.',
      );
    }

    return Hardware(cores: cores, threads: threads, memoryGb: memoryGb);
  }

  /// [value] as a whole number, refusing anything a count cannot be.
  static int _whole(Object? value, {required String field}) {
    final int? read = value is int ? value : int.tryParse('$value'.trim());
    if (read == null) {
      throwToolExit('$field holds "$value", which is not a whole number.');
    }

    return read;
  }

  /// [value] as gibibytes, written with the `g` a reader expects or without it.
  ///
  /// The suffix is optional because `memory: 8` and `memory: 8g` mean the same
  /// thing to anyone reading the file, and refusing one of them would be a rule
  /// nobody could guess.
  static int _gibibytes(Object? value, {required String field}) {
    final String written = '$value'.trim().toLowerCase();
    final int? read = int.tryParse(written.endsWith('g') ? written.substring(0, written.length - 1) : written);
    if (read == null) {
      throwToolExit('$field holds "$value", which does not name a number of gibibytes, as in "8g".');
    }

    return read;
  }

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
