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
