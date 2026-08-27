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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// The file a service's cost is declared in, inside an `ops/` directory.
const String capacityFileName = 'capacity.yaml';

/// The memory sizes a capacity file may be written in.
final RegExp _size = RegExp(r'^(\d+)(Mi|Gi)$');

/// One service, as the package that owns it declares it.
class ServiceCapacity {
  /// Holds one service as its package declared it.
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
  /// by [Capacity.total], which is why a package declares a weight rather than a
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

/// Every service the framework and its packages declare a cost for.
class Capacity {
  /// Gathers [services], budgeting only those that start under [profiles].
  Capacity(List<ServiceCapacity> services, {Set<String> profiles = const <String>{}})
    : services = List<ServiceCapacity>.unmodifiable(services),
      profiles = Set<String>.unmodifiable(profiles),
      total = services
          .where((ServiceCapacity service) => service.startsUnder(profiles))
          .fold<int>(0, (int sum, ServiceCapacity service) => sum + service.weight),
      _byKey = <String, ServiceCapacity>{for (final ServiceCapacity service in services) service.key: service};

  /// The Compose profiles the selection switches on.
  ///
  /// Held rather than only summed into [total] because [starting] answers a
  /// second question the budget asks: which services are actually going to be
  /// started, and so which of their floors the machine has to seat.
  final Set<String> profiles;

  /// Every declared service, in the order the files were read.
  ///
  /// A service behind a profile that is off is still here: the compose document
  /// declares it either way, so its limit has to be written even though Compose
  /// will not start it. What it does not get is a share. See [total].
  final List<ServiceCapacity> services;

  /// The sum of the weights of the services that actually start.
  ///
  /// Two things are excluded, for the same reason: a package the project did
  /// not mount, and a service under a profile nobody switched on. Neither of
  /// them takes memory, so neither of them may hold a share of it.
  final int total;

  final Map<String, ServiceCapacity> _byKey;

  /// The capacity of the socle and of [mounted], the mounted packages by default.
  ///
  /// [mounted] has to be the selection rather than every package found, and
  /// [profiles] the profiles that selection switches on: the weights are read
  /// against their own sum, so anything counted here takes a share of the
  /// machine whether or not a container of it ever starts.
  ///
  /// The socle's own file is read from the tool rather than from the framework
  /// checkout, because it describes the compose template the tool ships and the
  /// two would otherwise be free to describe different services.
  static Capacity load({List<Package>? mounted, Set<String> profiles = const <String>{}}) {
    final List<Package> found = mounted ?? Packages.load().active;

    return read(
      SocleOps().serviceDirectories.map((Directory d) => d.childFile('$capacityFileName$kTemplateSuffix')),
      found.expand((Package package) => package.fragments(capacityFileName)),
      profiles: profiles,
    );
  }

  /// The capacity declared by [socle] and by each of [packageFiles].
  ///
  /// [socle] is one file per service, each carrying the template suffix and
  /// sitting beside the compose it weighs, while a package writes a plain
  /// `capacity.yaml`. A package without one simply declares no service, which is
  /// the case of every package that ships no container.
  static Capacity read(Iterable<File> socle, Iterable<File> packageFiles, {Set<String> profiles = const <String>{}}) =>
      Capacity(<ServiceCapacity>[
        for (final File file in socle) ..._readFile(file, required: true),
        for (final File file in packageFiles) ..._readFile(file, required: false),
      ], profiles: profiles);

  /// The service named [key], or null when nothing declares it.
  ServiceCapacity? operator [](String key) => _byKey[key];

  /// The share of the memory budget [key] takes, against [total].
  ///
  /// The shares of the services that start therefore add up to one, and dropping
  /// a package makes each remaining service bigger rather than leaving a hole. A
  /// service behind a profile that is off gets a share on paper, above one when
  /// summed with the rest, which nothing enforces because nothing runs.
  ///
  /// Throws when [key] is unknown: a service present in a compose document and
  /// absent from every capacity file would otherwise get no limit at all, which
  /// is the one failure that shows up as an OOM rather than as an error.
  double shareOf(String key) {
    final ServiceCapacity? service = _byKey[key];
    if (service == null) {
      throwToolExit('No capacity.yaml gives $key a weight. Add it to the one of the package that owns it.');
    }

    return service.weight / total;
  }

  /// Every service that starts, and so every service that holds a share.
  ///
  /// The complement of what [total] leaves out: a service behind a profile
  /// nobody switched on is declared, gets a limit written, and is not here.
  Iterable<ServiceCapacity> get starting => services.where((ServiceCapacity s) => s.startsUnder(profiles));

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

    return <ServiceCapacity>[for (final Object? entry in document['services'] as YamlList) _readService(entry, file)];
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
