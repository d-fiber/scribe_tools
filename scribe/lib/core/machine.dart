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

class Machine {
  const Machine({required this.id, required this.cores, required this.threads, required this.memoryGb});

  final String id;
  final int cores;
  final int threads;
  final int memoryGb;

  String get label => '$id — $cores vCores, $memoryGb Go';

  @override
  String toString() => '$cores c / $threads t, $memoryGb Go';
}

const String autoMachineId = 'auto';

const List<Machine> machineCatalog = <Machine>[
  Machine(id: 'b3-8', cores: 2, threads: 2, memoryGb: 8),
  Machine(id: 'b3-16', cores: 4, threads: 4, memoryGb: 16),
  Machine(id: 'b3-32', cores: 8, threads: 8, memoryGb: 32),
  Machine(id: 'b3-64', cores: 16, threads: 16, memoryGb: 64),
  Machine(id: 'b3-128', cores: 32, threads: 32, memoryGb: 128),
  Machine(id: 'b3-256', cores: 64, threads: 64, memoryGb: 256),
  Machine(id: 'b3-512', cores: 128, threads: 128, memoryGb: 512),
];

const String autoMachineLabel = 'auto — detect the cores and RAM of this machine';

List<String> get machineIds => <String>[autoMachineId, for (final Machine machine in machineCatalog) machine.id];

List<String> get machineLabels => <String>[
  autoMachineLabel,
  for (final Machine machine in machineCatalog) machine.label,
];

Future<Machine> resolveMachine(String id) async {
  for (final Machine machine in machineCatalog) {
    if (machine.id == id) return machine;
  }
  return detectMachine();
}

Future<Machine> detectMachine() async {
  final int threads = await _threads();
  final int cores = await _cores(threads);
  final int memoryGb = await _memoryGb();

  return Machine(id: autoMachineId, cores: cores, threads: threads, memoryGb: memoryGb);
}

Future<int> _threads() async {
  final int? linux = await _intFrom('nproc', <String>['--all']);
  if (linux != null) return linux;

  final int? darwin = await _intFrom('sysctl', <String>['-n', 'hw.logicalcpu']);
  if (darwin != null) return darwin;

  return Platform.numberOfProcessors;
}

Future<int> _cores(int threads) async {
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

Future<int> _memoryGb() async {
  final File meminfo = File('/proc/meminfo');
  if (meminfo.existsSync()) {
    final RegExpMatch? match = RegExp(r'MemTotal:\s+(\d+) kB').firstMatch(meminfo.readAsStringSync());
    if (match != null) return (int.parse(match.group(1)!) / (1024 * 1024)).round();
  }

  final int? darwin = await _intFrom('sysctl', <String>['-n', 'hw.memsize']);
  if (darwin != null) return (darwin / (1024 * 1024 * 1024)).round();

  return 0;
}

Future<int?> _intFrom(String executable, List<String> args) async {
  final ProcessResult? result = await _run(executable, args);
  if (result == null || result.exitCode != 0) return null;

  return int.tryParse((result.stdout as String).trim());
}

Future<ProcessResult?> _run(String executable, List<String> args) async {
  try {
    return await Process.run(executable, args);
  } on ProcessException {
    return null;
  }
}
