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

import 'dart:math' as math;

import 'hardware.dart';

const double _budgetShare = 0.80;
const double _reservationShare = 0.47;
const double _oldSpaceShare = 0.70;
const int _v8Overhead = 96;
const double _inflightBodyShare = 0.15;

const Map<String, double> _memoryShares = <String, double>{
  'db': 0.2122,
  'opensearch': 0.1361,
  'api': 0.1299,
  'functions': 0.0661,
  'worker': 0.0661,
  'gorse': 0.0661,
  'realtime': 0.0661,
  'kong': 0.0489,
  'redis': 0.0432,
  'imgproxy': 0.0280,
  'auth': 0.0207,
  'storage': 0.0188,
  'rest': 0.0125,
  'nats': 0.0113,
  'caddy': 0.0093,
  'vpn_admins': 0.0037,
  'db_migrate': 0.0037,
  'db_dev_confirm': 0.0019,
  'opensearch_setup': 0.0019,
  'realtime_init': 0.0019,
  'storage_init': 0.0019,
};

const Set<String> _oneShot = <String>{
  'db_migrate',
  'db_dev_confirm',
  'opensearch_setup',
  'realtime_init',
  'storage_init',
};

const Map<String, int> _replicated = <String, int>{'api': 0, 'rest': 1, 'storage': 2};

const Map<String, int> _aggregateShares = <String, int>{
  'api': 16384,
  'rest': 8192,
  'storage': 4096,
};

const int _minShares = 256;

int _clamp(num value, int low, int high) => math.max(low, math.min(high, value.round()));

String _mib(num megabytes) {
  final int value = math.max(16, megabytes.round());
  if (value < 1024) return '${value}m';
  return '${(value / 1024).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}g';
}

class SizingRules {
  const SizingRules(this.hardware);

  final Hardware hardware;

  int get _ramMb => hardware.memoryGb * 1024;
  double get _budget => _ramMb * _budgetShare;

  int get apiReplicas => _clamp(hardware.threads * 0.5, 1, 64);
  int get restReplicas => _clamp(hardware.cores / 4, 1, 16);
  int get storageReplicas => _clamp(hardware.cores / 6, 1, 8);

  int _replicasFor(String service) => switch (service) {
    'api' => apiReplicas,
    'rest' => restReplicas,
    'storage' => storageReplicas,
    _ => 1,
  };

  double _memoryFor(String service) => _budget * _memoryShares[service]! / _replicasFor(service);

  int _parallelism(int divisor) => _clamp(hardware.cores / divisor, 1, 16);

  /// What Postgres keeps for everything the calculation does not name.
  ///
  /// The migration job, the pg_cron workers, the hosts that dial the database
  /// directly and the connections Postgres reserves for a superuser. Every pool
  /// is counted below, so this covers the consumers that open a handful of
  /// connections and close them again.
  static const int _connectionReserve = 30;

  String get profiles {
    final int ram = hardware.memoryGb;
    if (ram < 8) return '';
    if (ram < 12) return 'search,realtime';
    if (ram < 24) return 'search,realtime,reco';
    return 'search,realtime,reco,ops';
  }

  Map<String, String> resolve() {
    final Map<String, String> values = <String, String>{};

    for (final MapEntry<String, double> entry in _memoryShares.entries) {
      final double limit = _memoryFor(entry.key);
      values['${entry.key}_mem_limit'] = _mib(limit);
      if (!_oneShot.contains(entry.key)) {
        values['${entry.key}_mem_res'] = _mib(limit * _reservationShare);
      }
    }

    for (final MapEntry<String, int> entry in _replicated.entries) {
      final int replicas = _replicasFor(entry.key);
      values['${entry.key}_replicas'] = '$replicas';
      values['${entry.key}_cpu_shares'] =
          '${math.max(_minShares, _aggregateShares[entry.key]! ~/ replicas)}';
    }

    final double dbMb = _memoryFor('db');
    values['db_shared_buffers'] = '${math.min(dbMb * 0.25, 16 * 1024).round()}MB';
    values['db_effective_cache_size'] = '${(_ramMb * 0.50).round()}MB';
    values['db_work_mem'] = '${_clamp(dbMb * 0.01, 4, 32)}MB';
    values['db_maintenance_work_mem'] = '${_clamp(dbMb * 0.06, 64, 2048)}MB';
    values['db_wal_buffers'] = '${_clamp(dbMb * 0.03, 4, 64)}MB';
    values['db_max_worker_processes'] = '${_clamp(hardware.cores, 8, 64)}';
    values['db_max_parallel_workers'] = '${_clamp(hardware.cores / 2, 2, 16)}';
    values['db_max_parallel_workers_per_gather'] = '${_clamp(hardware.cores / 8, 1, 4)}';

    final int restPoolTotal = _clamp(hardware.cores * 2, 8, 64);
    final int authPool = _clamp(hardware.cores, 4, 32);
    values['rest_db_pool'] = '${math.max(4, restPoolTotal ~/ restReplicas)}';
    values['auth_db_pool'] = '$authPool';
    final int connectionFloor = restPoolTotal + authPool + _connectionReserve;
    values['db_max_connections'] = '${math.max(_clamp(hardware.cores * 8, 60, 400), connectionFloor)}';

    // Half, not three quarters: rewriting the append-only file doubles the
    // footprint, so a container sized on maxmemory alone is killed during a
    // rewrite. See `.claude/scribe/ops/docker/global.md`.
    values['redis_maxmemory'] = '${(_memoryFor('redis') * 0.50).round()}mb';
    values['redis_io_threads'] = '${_clamp(hardware.cores / 8, 1, 8)}';
    values['redis_io_threads_do_reads'] = hardware.cores > 8 ? 'yes' : 'no';

    // The floor used to be 64, applied without looking at what the replica was
    // actually given: on a machine with more threads than gibibytes the api
    // replica gets ~53 MiB and V8 was still told it could take 64, so the
    // process was allowed past its own cgroup before the collector felt any
    // pressure. 16 matches the floor `_mib` already applies to the limits
    // themselves, which keeps the flag under the container on every shape.
    //
    // This bounds the V8 heap and nothing else. Request bodies live in external
    // buffers the flag does not govern, so it is not the lever for an OOM under
    // load. See `.claude/scribe/ops/global.md`.
    values['api_max_old_space'] = '${_clamp(_memoryFor('api') * _oldSpaceShare - _v8Overhead, 16, 8192)}';
    // Request bodies live in external buffers, outside the heap the flag above
    // bounds. The two therefore add up, and the budget was a fixed 256 MiB
    // against replicas that can be smaller than that. Fifteen percent leaves
    // the heap its share and still admits real bodies.
    values['api_max_inflight_body'] = '${_clamp(_memoryFor('api') * _inflightBodyShare, 8, 1024)}';
    values['worker_max_old_space'] = '${_clamp(_memoryFor('worker') * _oldSpaceShare - _v8Overhead, 16, 8192)}';

    values['opensearch_heap'] = _mib(math.min(_memoryFor('opensearch') * 0.5, 31 * 1024));
    values['opensearch_node_processors'] = '${_clamp(hardware.cores / 2, 1, 16)}';

    values['kong_nginx_worker_processes'] = '${_parallelism(4)}';
    values['kong_keepalive_pool'] = '${_clamp(hardware.cores * 32, 128, 2048)}';
    values['rest_ghc_rts'] = '-N${_parallelism(4)}';
    values['auth_gomaxprocs'] = '${_parallelism(4)}';
    values['imgproxy_gomaxprocs'] = '${_parallelism(4)}';
    values['imgproxy_workers'] = '${_clamp(hardware.cores / 2, 2, 16)}';
    values['gorse_gomaxprocs'] = '${_parallelism(6)}';
    values['nats_gomaxprocs'] = '${_parallelism(6)}';
    values['storage_uv_threadpool'] = '${_clamp(hardware.cores / 2, 4, 16)}';

    values['realtime_schedulers'] = '${_parallelism(4)}';
    values['realtime_max_connections'] = '${_clamp(hardware.threads * 2000, 2000, 64000)}';
    values['realtime_num_acceptors'] = '${_clamp(hardware.cores * 10, 20, 200)}';
    values['realtime_rlimit_nofile'] = '65535';

    values['opensearch_cpu_limit'] = _cpuCap(0.35, 0.5, 12);
    values['gorse_cpu_limit'] = _cpuCap(0.20, 0.25, 6);

    values['compose_profiles'] = profiles;

    return values;
  }

  String _cpuCap(double share, double low, double high) {
    final double value = math.max(low, math.min(high, hardware.cores * share));
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
