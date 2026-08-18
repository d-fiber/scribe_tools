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

import 'package:scribe/src/ops/capacity.dart';
import 'package:scribe/src/ops/hardware.dart';

const double _budgetShare = 0.80;
const double _reservationShare = 0.47;
const double _oldSpaceShare = 0.70;
const int _v8Overhead = 96;
const double _inflightBodyShare = 0.15;


const int _minShares = 256;

int _clamp(num value, int low, int high) => math.max(low, math.min(high, value.round()));

String _mib(num megabytes) {
  final int value = math.max(16, megabytes.round());
  if (value < 1024) return '${value}m';
  return '${(value / 1024).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}g';
}

/// Every value the compose templates take, derived from [hardware].
class SizingRules {
  const SizingRules(this.hardware, this.capacity);

  final Hardware hardware;

  /// What each service declares it costs, read from the capacity files.
  final Capacity capacity;

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

  double _memoryFor(String service) => _budget * capacity.shareOf(service) / _replicasFor(service);

  int _parallelism(int divisor) => _clamp(hardware.cores / divisor, 1, 16);

  /// The placeholder values, keyed the way the templates spell them.
  ///
  /// Everything is driven by [capacity]: a service the selection left out gets
  /// neither a limit nor a setting, because the fragment that would have read
  /// them is not merged either.
  Map<String, String> resolve() {
    final Map<String, String> values = <String, String>{};

    for (final ServiceCapacity service in capacity.services) {
      final double limit = _memoryFor(service.key);
      values['${service.key}_mem_limit'] = _mib(limit);
      if (!service.isOneShot) {
        values['${service.key}_mem_res'] = _mib(limit * _reservationShare);
      }
      values.addAll(_tunables(service));
    }

    for (final ServiceCapacity service in capacity.replicated) {
      final int replicas = _replicasFor(service.key);
      values['${service.key}_replicas'] = '$replicas';
      values['${service.key}_cpu_shares'] = '${math.max(_minShares, service.cpuSharesTotal! ~/ replicas)}';
    }

    return values;
  }

  int get _restPoolTotal => _clamp(hardware.cores * 2, 8, 64);
  int get _authPool => _clamp(hardware.cores, 4, 32);

  /// What Postgres keeps for everything the calculation does not name.
  ///
  /// The migration job, the pg_cron workers, the hosts that dial the database
  /// directly and the connections Postgres reserves for a superuser. Every pool
  /// is counted below, so this covers the consumers that open a handful of
  /// connections and close them again.
  static const int _connectionReserve = 30;

  /// The connections Postgres has to be able to seat before anything else.
  ///
  /// Postgres has to seat every pool that dials it, whatever the core count
  /// would have asked for on its own. `db_max_connections` is therefore the
  /// larger of the two, and never the core count alone.
  int get _connectionFloor => _restPoolTotal + _authPool + _connectionReserve;

  /// What [service] turns its memory and its cores into, as engine settings.
  ///
  /// Keyed by service and not by [ServiceCapacity.runtime], because the runtime
  /// says which knobs exist and not which of them this service uses: `api` and
  /// `functions` are both `deno` and only one bounds its heap, `auth` and `nats`
  /// are both `go` and only one takes a database pool.
  Map<String, String> _tunables(ServiceCapacity service) {
    final double memory = _memoryFor(service.key);

    return switch (service.key) {
      'db' => <String, String>{
        'db_shared_buffers': '${math.min(memory * 0.25, 16 * 1024).round()}MB',
        'db_effective_cache_size': '${(_ramMb * 0.50).round()}MB',
        'db_work_mem': '${_clamp(memory * 0.01, 4, 32)}MB',
        'db_maintenance_work_mem': '${_clamp(memory * 0.06, 64, 2048)}MB',
        'db_wal_buffers': '${_clamp(memory * 0.03, 4, 64)}MB',
        'db_max_worker_processes': '${_clamp(hardware.cores, 8, 64)}',
        'db_max_parallel_workers': '${_clamp(hardware.cores / 2, 2, 16)}',
        'db_max_parallel_workers_per_gather': '${_clamp(hardware.cores / 8, 1, 4)}',
        'db_max_connections': '${math.max(_clamp(hardware.cores * 8, 60, 400), _connectionFloor)}',
      },
      'rest' => <String, String>{
        'rest_db_pool': '${math.max(4, _restPoolTotal ~/ restReplicas)}',
        'rest_ghc_rts': '-N${_parallelism(4)}',
      },
      'auth' => <String, String>{
        'auth_db_pool': '$_authPool',
        'auth_gomaxprocs': '${_parallelism(4)}',
      },
      'redis' => <String, String>{
        // Half, not three quarters: rewriting the append-only file doubles the
        // footprint, so a container sized on maxmemory alone is killed during a
        // rewrite. See `.claude/scribe/ops/docker/global.md`.
        'redis_maxmemory': '${(memory * 0.50).round()}mb',
        'redis_io_threads': '${_clamp(hardware.cores / 8, 1, 8)}',
        'redis_io_threads_do_reads': hardware.cores > 8 ? 'yes' : 'no',
      },
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
      'api' => <String, String>{
        'api_max_old_space': '${_clamp(memory * _oldSpaceShare - _v8Overhead, 16, 8192)}',
        // Request bodies live in external buffers, outside the heap the flag
        // above bounds. The two therefore add up, and the budget was a fixed
        // 256 MiB against replicas that can be smaller than that. Fifteen
        // percent leaves the heap its share and still admits real bodies.
        'api_max_inflight_body': '${_clamp(memory * _inflightBodyShare, 8, 1024)}',
      },
      'worker' => <String, String>{
        'worker_max_old_space': '${_clamp(memory * _oldSpaceShare - _v8Overhead, 16, 8192)}',
      },
      'kong' => <String, String>{
        'kong_nginx_worker_processes': '${_parallelism(4)}',
        'kong_keepalive_pool': '${_clamp(hardware.cores * 32, 128, 2048)}',
      },
      'nats' => <String, String>{'nats_gomaxprocs': '${_parallelism(6)}'},
      'storage' => <String, String>{'storage_uv_threadpool': '${_clamp(hardware.cores / 2, 4, 16)}'},
      'imgproxy' => <String, String>{
        'imgproxy_gomaxprocs': '${_parallelism(4)}',
        'imgproxy_workers': '${_clamp(hardware.cores / 2, 2, 16)}',
      },
      'realtime' => <String, String>{
        'realtime_schedulers': '${_parallelism(4)}',
        'realtime_max_connections': '${_clamp(hardware.threads * 2000, 2000, 64000)}',
        'realtime_num_acceptors': '${_clamp(hardware.cores * 10, 20, 200)}',
        'realtime_rlimit_nofile': '65535',
      },
      'opensearch' => <String, String>{
        'opensearch_heap': _mib(math.min(memory * 0.5, 31 * 1024)),
        'opensearch_node_processors': '${_clamp(hardware.cores / 2, 1, 16)}',
        'opensearch_cpu_limit': _cpuCap(0.35, 0.5, 12),
      },
      'gorse' => <String, String>{
        'gorse_gomaxprocs': '${_parallelism(6)}',
        'gorse_cpu_limit': _cpuCap(0.20, 0.25, 6),
      },
      _ => const <String, String>{},
    };
  }

  String _cpuCap(double share, double low, double high) {
    final double value = math.max(low, math.min(high, hardware.cores * share));
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
