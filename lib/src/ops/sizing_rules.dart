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

import 'dart:math' as math;

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/ops/capacity.dart';
import 'package:scribe_tools/src/ops/hardware.dart';

const double _budgetShare = 0.80;
const double _reservationShare = 0.47;
const double _oldSpaceShare = 0.70;
const int _v8Overhead = 96;
const int _bootableHeap = 32;
const double _inflightBodyShare = 0.15;

const int _minShares = 256;

int _clamp(num value, int low, int high) => math.max(low, math.min(high, value.round()));

/// [megabytes] as a whole number of mebibytes, for a reader that refuses a fraction.
///
/// `_mib` shortens anything above a gibibyte to two decimals, which Docker reads
/// and a JVM does not: `-Xms1.58g` fails with `Invalid initial heap size` and the
/// process never starts. Every value that lands in a `-Xm` flag comes through
/// here instead.
String _wholeMib(num megabytes) => '${math.max(16, megabytes.round())}m';

String _mib(num megabytes) {
  final int value = math.max(16, megabytes.round());
  if (value < 1024) return '${value}m';
  return '${(value / 1024).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}g';
}

/// Every value the compose templates take, derived from [hardware].
class SizingRules {
  /// Derives every value from [hardware], sharing it out according to [capacity].
  const SizingRules(this.hardware, this.capacity, {this.cpuCap = false});

  /// Whether a service gets a hard CPU ceiling on top of its relative share.
  ///
  /// A share decides who yields under contention and bounds nothing, which is
  /// what a machine dedicated to one stack wants: an idle neighbour lends its
  /// cores instead of leaving them unused. A machine shared with anything else
  /// wants the ceiling, and pays for it by never bursting past its slice.
  final bool cpuCap;

  /// The machine every value below is derived from.
  final Hardware hardware;

  /// What each service declares it costs, read from the capacity files.
  final Capacity capacity;

  int get _ramMb => hardware.memoryGb * 1024;
  double get _budget => _ramMb * _budgetShare;

  /// How many api containers to start, one per two hardware threads, capped at 64.
  int get apiReplicas => _clamp(hardware.threads * 0.5, 1, 64);

  /// How many rest containers to start, one per four cores, capped at 16.
  int get restReplicas => _clamp(hardware.cores / 4, 1, 16);

  /// How many storage containers to start, one per six cores, capped at 8.
  int get storageReplicas => _clamp(hardware.cores / 6, 1, 8);

  int _replicasFor(String service) => switch (service) {
    'api' => apiReplicas,
    'rest' => restReplicas,
    'storage' => storageReplicas,
    _ => 1,
  };

  /// The memory limit one container of [service] gets, in mebibytes.
  ///
  /// A share of the budget, never below the floor the capacity file declares
  /// under `min`. The floor is per container and so is compared against the
  /// share after it has been split, because it is what one container needs to
  /// hold its own working set rather than what the service needs in total.
  double _memoryFor(ServiceCapacity service) =>
      math.max(service.minMib.toDouble(), _budget * capacity.shareOf(service.key) / _replicasFor(service.key));

  /// What the services that start need between them before any of them answers.
  ///
  /// A replicated service counts once per container, since that is how many
  /// floors the machine actually has to seat.
  int get _floorTotal =>
      capacity.starting.fold(0, (int sum, ServiceCapacity s) => sum + s.minMib * _replicasFor(s.key));

  /// Refuses a machine whose budget cannot seat the floors of what starts.
  ///
  /// Handing each service its floor anyway would promise more memory than the
  /// machine has, which Compose accepts and the kernel settles later by killing
  /// whichever container reached for the last of it.
  void _refuseAMachineTooSmall() {
    final int floors = _floorTotal;
    if (floors <= _budget) return;

    throwToolExit(
      'The stack does not fit on $hardware: the budget leaves ${_budget.round()} MiB to share out, and the services '
      'that start need $floors MiB between them before any of them answers, so ${(floors - _budget).round()} MiB is '
      'missing.\n'
      'Give the machine more memory, or drop a package from config.yaml so that fewer services claim a floor.',
    );
  }

  int _parallelism(int divisor) => _clamp(hardware.cores / divisor, 1, 16);

  /// The placeholder values, keyed the way the templates spell them.
  ///
  /// Everything is driven by [capacity]: a service the selection left out gets
  /// neither a limit nor a setting, because the fragment that would have read
  /// them is not merged either.
  Map<String, String> resolve() {
    _refuseAMachineTooSmall();

    final Map<String, String> values = <String, String>{};

    for (final ServiceCapacity service in capacity.services) {
      final double limit = _memoryFor(service);
      values['${service.key}_mem_limit'] = _mib(limit);
      if (!service.isOneShot) {
        values['${service.key}_mem_res'] = _mib(limit * _reservationShare);
      }
      values['${service.key}_cpu_ceiling'] = _ceilingLineFor(service);
      values.addAll(_tunables(service));
    }

    for (final ServiceCapacity service in capacity.replicated) {
      final int replicas = _replicasFor(service.key);
      values['${service.key}_replicas'] = '$replicas';
      values['${service.key}_cpu_shares'] = '${math.max(_minShares, service.cpuSharesTotal! ~/ replicas)}';
    }

    return values;
  }

  /// The ceiling line [service]'s limits carry, empty when the target wants none.
  ///
  /// It is rendered rather than written in the template because a template that
  /// named the value directly would fail to render on every target that does not
  /// cap, and a value of zero would be read by Compose as no CPU at all.
  String _ceilingLineFor(ServiceCapacity service) =>
      cpuCap ? '\n          cpus: "${_cpusFor(service.key).toStringAsFixed(2)}"' : '';

  /// The share of the machine's cores [service] may take, as a ceiling.
  ///
  /// It is the share the memory is cut by, applied to the cores, and never below
  /// a tenth of a core: a service pinned under that cannot answer a health
  /// check, and a stack that fails its probes is worse than one that lends a
  /// neighbour slightly more than its share.
  double _cpusFor(String service) {
    final double share = capacity.shareOf(service) / _replicasFor(service);

    return math.max(0.1, (hardware.cores * share * 100).roundToDouble() / 100);
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
    final double memory = _memoryFor(service);

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
      'auth' => <String, String>{'auth_db_pool': '$_authPool', 'auth_gomaxprocs': '${_parallelism(4)}'},
      'redis' => <String, String>{
        // Half, not three quarters: rewriting the append-only file doubles the
        // footprint, so a container sized on maxmemory alone is killed during a
        // rewrite. See `.claude/scribe/ops/docker/global.md`.
        'redis_maxmemory': '${(memory * 0.50).round()}mb',
        'redis_io_threads': '${_clamp(hardware.cores / 8, 1, 8)}',
        'redis_io_threads_do_reads': hardware.cores > 8 ? 'yes' : 'no',
      },
      // The lower bound is the smallest heap this engine was seen to boot on:
      // at 16 MiB it dies with `Fatal JavaScript out of memory` before serving
      // anything, and at 32 MiB it answers. A service that reaches the bound
      // has a floor too low for its runtime, and the bound keeps it bootable
      // instead of hiding the mistake behind a restart loop.
      'api' => <String, String>{
        'api_max_old_space': '${_clamp(memory * _oldSpaceShare - _v8Overhead, _bootableHeap, 8192)}',
        // Request bodies live in external buffers, outside the heap the flag
        // above bounds. The two therefore add up, and the budget was a fixed
        // 256 MiB against replicas that can be smaller than that. Fifteen
        // percent leaves the heap its share and still admits real bodies.
        'api_max_inflight_body': '${_clamp(memory * _inflightBodyShare, 8, 1024)}',
      },
      'worker' => <String, String>{
        'worker_max_old_space': '${_clamp(memory * _oldSpaceShare - _v8Overhead, _bootableHeap, 8192)}',
      },
      'kong' => <String, String>{
        'kong_nginx_worker_processes': '${_parallelism(4)}',
        'kong_keepalive_pool': '${_clamp(hardware.cores * 32, 128, 2048)}',
      },
      'nats' => <String, String>{
        'nats_gomaxprocs': '${_parallelism(6)}',
        // A stream nobody trims fills the host disk, and the cluster shares it.
        // Half the queue's own budget is what JetStream may keep, which bounds
        // the damage to what the machine already set aside for it.
        'nats_store_limit': '${(memory * 0.50).round()}MB',
        'nats_memory_store': '${(memory * 0.25).round()}MB',
      },
      'storage' => <String, String>{'storage_uv_threadpool': '${_clamp(hardware.cores / 2, 4, 16)}'},
      'imgproxy' => <String, String>{
        'imgproxy_gomaxprocs': '${_parallelism(4)}',
        'imgproxy_workers': '${_clamp(hardware.cores / 2, 2, 16)}',
      },
      'realtime' => <String, String>{
        'realtime_schedulers': '${_parallelism(4)}',
        'realtime_max_connections': '${_realtimeConnections(memory)}',
        'realtime_num_acceptors': '${_clamp(hardware.cores * 10, 20, 200)}',
        'realtime_rlimit_nofile': '65535',
      },
      'opensearch' => <String, String>{
        'opensearch_heap': _wholeMib(math.min(memory * 0.5, 31 * 1024)),
        'opensearch_node_processors': '${_clamp(hardware.cores / 2, 1, 16)}',
        'opensearch_cpu_limit': _cpuCap(0.35, 0.5, 12),
      },
      _ => const <String, String>{},
    };
  }

  /// What an idle realtime container holds, in mebibytes.
  ///
  /// Measured on `supabase/realtime:v2.76.5` with no listener connected. The
  /// BEAM does not hand memory back when a connection closes, so this is a
  /// floor the container never drops under and not an average it hovers around.
  static const int _realtimeIdleMib = 265;

  /// What one websocket connection holds, in kibibytes.
  ///
  /// Measured flat between 50 and 300 listeners. Below fifty the idle footprint
  /// weighs more than the connections and the figure reads far too high.
  static const double _realtimeConnectionKib = 190;

  /// How many websocket connections [memory] mebibytes seat.
  ///
  /// The core count alone used to decide this, without looking at the limit the
  /// same calculation had just written: on eight gibibytes the container
  /// announced sixteen thousand connections and could hold nine hundred, so the
  /// OOM killer arrived long before `MAX_CONNECTIONS` ever did. Both bounds are
  /// therefore applied, and the smaller one wins.
  ///
  /// The lower bound of a hundred is out of reach while the service declares a
  /// floor above its idle footprint, and stands for a capacity file that lowers
  /// one or raises the other.
  int _realtimeConnections(double memory) {
    final double seated = (memory - _realtimeIdleMib) * 1024 / _realtimeConnectionKib;
    return _clamp(math.min(hardware.threads * 2000, seated), 100, 64000);
  }

  String _cpuCap(double share, double low, double high) {
    final double value = math.max(low, math.min(high, hardware.cores * share));
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
