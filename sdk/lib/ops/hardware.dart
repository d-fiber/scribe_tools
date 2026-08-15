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

import 'dart:io';

class Hardware {
  const Hardware({
    required this.cores,
    required this.threads,
    required this.memoryGb,
  });

  final int cores;
  final int threads;
  final int memoryGb;

  @override
  String toString() => '$cores c / $threads t, $memoryGb Go';

  static Future<Hardware> detect() async {
    final int threads = await _threads();
    final int cores = await _cores(threads);
    final int memoryGb = await _memoryGb();

    return Hardware(cores: cores, threads: threads, memoryGb: memoryGb);
  }

  static Future<int> _threads() async {
    final int? linux = await _intFrom('nproc', <String>['--all']);
    if (linux != null) return linux;

    final int? darwin = await _intFrom('sysctl', <String>['-n', 'hw.logicalcpu']);
    if (darwin != null) return darwin;

    return Platform.numberOfProcessors;
  }

  static Future<int> _cores(int threads) async {
    final int? darwin = await _intFrom('sysctl', <String>['-n', 'hw.physicalcpu']);
    if (darwin != null) return darwin;

    final ProcessResult? lscpu = await _run('lscpu', <String>['-p=Core,Socket']);
    if (lscpu != null && lscpu.exitCode == 0) {
      final Set<String> unique = <String>{
        for (final String raw in (lscpu.stdout as String).split('\n'))
          if (raw.trim().isNotEmpty && !raw.startsWith('#')) raw.trim(),
      };
      if (unique.isNotEmpty) return unique.length;
    }

    return threads;
  }

  static Future<int> _memoryGb() async {
    final File meminfo = File('/proc/meminfo');
    if (meminfo.existsSync()) {
      final RegExpMatch? match = RegExp(r'MemTotal:\s+(\d+) kB').firstMatch(meminfo.readAsStringSync());
      if (match != null) return (int.parse(match.group(1)!) / (1024 * 1024)).round();
    }

    final int? darwin = await _intFrom('sysctl', <String>['-n', 'hw.memsize']);
    if (darwin != null) return (darwin / (1024 * 1024 * 1024)).round();

    return 0;
  }

  static Future<int?> _intFrom(String executable, List<String> args) async {
    final ProcessResult? result = await _run(executable, args);
    if (result == null || result.exitCode != 0) return null;

    return int.tryParse((result.stdout as String).trim());
  }

  static Future<ProcessResult?> _run(String executable, List<String> args) async {
    try {
      return await Process.run(executable, args);
    } on ProcessException {
      return null;
    }
  }
}

