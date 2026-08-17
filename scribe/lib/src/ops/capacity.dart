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

import 'package:file/file.dart';
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/dependencies.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';
import 'package:yaml/yaml.dart';

/// The file a service's cost is declared in, inside an `ops/` directory.
const String capacityFileName = 'capacity.yaml';

/// The memory sizes a capacity file may be written in.
final RegExp _size = RegExp(r'^(\d+)(Mi|Gi)$');

/// One service, as the module that owns it declares it.
class ServiceCapacity {
  const ServiceCapacity({
    required this.name,
    required this.weight,
    required this.runtime,
    required this.minMib,
    required this.devMib,
    this.profile,
    this.cpuShares,
    this.cpuSharesTotal,
  });

  /// The Compose service name, hyphens and all.
  final String name;

  /// Its pull on the memory budget, relative to the other loaded services.
  ///
  /// The number means nothing on its own. It only becomes a share once divided
  /// by [Capacity.total], which is why a module declares a weight rather than a
  /// percentage: a percentage would be wrong as soon as a neighbour is dropped.
  final int weight;

  /// What its memory and cores become as settings, from a closed vocabulary.
  final String runtime;

  /// The Compose profile it starts under, null when it always starts.
  ///
  /// This repeats what the compose fragment says, and a test refuses the two
  /// disagreeing. It is here because the budget is shared out here: a service
  /// under a profile nobody switched on still gets a limit written, and must
  /// not take a share of a machine it is not running on.
  final String? profile;

  /// The floor below which it does not start, in mebibytes.
  final int minMib;

  /// The floor below which it starts but does not serve, in mebibytes.
  final int devMib;

  /// Its relative CPU weight, when it is never replicated.
  final int? cpuShares;

  /// Its relative CPU weight in total, split across its replicas.
  final int? cpuSharesTotal;

  /// The name the templates spell it with, which uses underscores.
  String get key => name.replaceAll('-', '_');

  /// Whether it runs once and exits, and so takes a limit but no reservation.
  bool get isOneShot => runtime == 'oneshot';

  /// Whether the number of its containers depends on the machine.
  bool get isReplicated => cpuSharesTotal != null;

  /// Whether Compose starts it when [profiles] are the profiles switched on.
  bool startsUnder(Set<String> profiles) => profile == null || profiles.contains(profile);
}

/// Every service the framework and its modules declare a cost for.
class Capacity {
  Capacity(List<ServiceCapacity> services, {Set<String> profiles = const <String>{}})
    : services = List<ServiceCapacity>.unmodifiable(services),
      total = services
          .where((ServiceCapacity service) => service.startsUnder(profiles))
          .fold<int>(0, (int sum, ServiceCapacity service) => sum + service.weight),
      _byKey = <String, ServiceCapacity>{
        for (final ServiceCapacity service in services) service.key: service,
      };

  /// Every declared service, in the order the files were read.
  ///
  /// A service behind a profile that is off is still here: the compose document
  /// declares it either way, so its limit has to be written even though Compose
  /// will not start it. What it does not get is a share. See [total].
  final List<ServiceCapacity> services;

  /// The sum of the weights of the services that actually start.
  ///
  /// Two things are excluded, for the same reason: a module the project did not
  /// mount, and a service under a profile nobody switched on. Neither of them
  /// takes memory, so neither of them may hold a share of it.
  final int total;

  final Map<String, ServiceCapacity> _byKey;

  /// The capacity of [project] and of [modules], the mounted ones by default.
  ///
  /// [modules] has to be the selection rather than every module found, and
  /// [profiles] the profiles that selection switches on: the weights are read
  /// against their own sum, so anything counted here takes a share of the
  /// machine whether or not a container of it ever starts.
  static Capacity load({Project? project, List<Dependency>? modules, Set<String> profiles = const <String>{}}) {
    final Project target = project ?? globals.project;
    final List<Dependency> found = modules ?? Dependencies.load().active;

    return read(
      target.sdk.ops.childDirectory('docker'),
      found.map((Dependency d) => d.fragment(capacityFileName)),
      profiles: profiles,
    );
  }

  /// The capacity declared in [socle] and in each of [moduleFiles].
  ///
  /// A module without a capacity file simply declares no service, which is the
  /// case of every module that ships no container.
  static Capacity read(Directory socle, Iterable<File> moduleFiles, {Set<String> profiles = const <String>{}}) =>
      Capacity(<ServiceCapacity>[
        ..._readFile(socle.childFile(capacityFileName), required: true),
        for (final File file in moduleFiles) ..._readFile(file, required: false),
      ], profiles: profiles);

  /// The service named [key], or null when nothing declares it.
  ServiceCapacity? operator [](String key) => _byKey[key];

  /// The share of the memory budget [key] takes, against [total].
  ///
  /// The shares of the services that start therefore add up to one, and dropping
  /// a module makes each remaining service bigger rather than leaving a hole. A
  /// service behind a profile that is off gets a share on paper, above one when
  /// summed with the rest, which nothing enforces because nothing runs.
  ///
  /// Throws when [key] is unknown: a service present in a compose document and
  /// absent from every capacity file would otherwise get no limit at all, which
  /// is the one failure that shows up as an OOM rather than as an error.
  double shareOf(String key) {
    final ServiceCapacity? service = _byKey[key];
    if (service == null) {
      throwToolExit('No capacity.yaml gives $key a weight. Add it to the one of the module that owns it.');
    }

    return service.weight / total;
  }

  /// Every service whose container count depends on the machine.
  Iterable<ServiceCapacity> get replicated => services.where((ServiceCapacity s) => s.isReplicated);

  static List<ServiceCapacity> _readFile(File file, {required bool required}) {
    if (!file.existsSync()) {
      if (!required) return const <ServiceCapacity>[];
      throwToolExit('No capacity file at ${file.path}');
    }

    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap || document['services'] is! YamlList) {
      throwToolExit('${file.path}: the file must be a list under "services".');
    }

    return <ServiceCapacity>[
      for (final Object? entry in document['services'] as YamlList) _readService(entry, file),
    ];
  }

  static ServiceCapacity _readService(Object? entry, File file) {
    if (entry is! YamlMap) {
      throwToolExit('${file.path}: every service must be a mapping.');
    }

    return ServiceCapacity(
      name: _string(entry, 'name', file),
      weight: _int(entry, 'weight', file),
      runtime: _string(entry, 'runtime', file),
      minMib: _mib(_string(entry, 'min', file), file),
      devMib: _mib(_string(entry, 'dev', file), file),
      profile: entry['profile'] as String?,
      cpuShares: entry['cpu_shares'] as int?,
      cpuSharesTotal: entry['cpu_shares_total'] as int?,
    );
  }

  static String _string(YamlMap node, String key, File file) {
    final Object? value = node[key];
    if (value is! String) throwToolExit('${file.path}: "$key" is missing, or is not text.');

    return value;
  }

  static int _int(YamlMap node, String key, File file) {
    final Object? value = node[key];
    if (value is! int) throwToolExit('${file.path}: "$key" is missing, or is not an integer.');

    return value;
  }

  static int _mib(String value, File file) {
    final RegExpMatch? match = _size.firstMatch(value);
    if (match == null) throwToolExit('${file.path}: size "$value" is not one of 256Mi or 1Gi.');

    final int amount = int.parse(match.group(1)!);

    return match.group(2) == 'Gi' ? amount * 1024 : amount;
  }
}
