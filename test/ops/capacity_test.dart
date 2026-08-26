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
import 'package:scribe_tools/src/ops/capacity.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'capacity_source.dart';

/// What a service's memory and cores may be translated into.
///
/// Closed on purpose: a package declares what it is, not how it is tuned, so a
/// runtime nobody implements has to fail here rather than silently mean
/// "nothing to set".
const Set<String> _runtimes = <String>{
  'postgres',
  'redis',
  'erlang',
  'jvm',
  'deno',
  'haskell',
  'nginx',
  'go',
  'node',
  'oneshot',
  'plain',
};

void main() {
  late Capacity capacity;

  setUp(() => capacity = frameworkCapacity());

  group('the capacity files of the framework', () {
    test('declare a runtime the code knows how to tune', () {
      final List<String> unknown = <String>[
        for (final ServiceCapacity service in capacity.services)
          if (!_runtimes.contains(service.runtime)) '${service.name}: ${service.runtime}',
      ];

      expect(unknown, isEmpty);
    });

    test('never ask for less in dev than the service needs to start', () {
      final List<String> inverted = <String>[
        for (final ServiceCapacity service in capacity.services)
          if (service.devMib < service.minMib) '${service.name}: dev ${service.devMib} < min ${service.minMib}',
      ];

      expect(inverted, isEmpty);
    });

    test('name a service no more than once across every file', () {
      final Set<String> seen = <String>{};
      final List<String> twice = <String>[
        for (final ServiceCapacity service in capacity.services)
          if (!seen.add(service.key)) service.name,
      ];

      expect(twice, isEmpty, reason: 'two weights for one service would make the sum wrong');
    });

    test('give a cpu weight in the form the service is deployed in', () {
      final List<String> wrong = <String>[
        for (final ServiceCapacity service in capacity.services)
          if (service.isReplicated && service.cpuShares != null)
            '${service.name}: replicated, so its CPU weight is a total'
          else if (!service.isReplicated && service.cpuSharesTotal != null)
            '${service.name}: never replicated, so its CPU weight is not a total',
      ];

      expect(wrong, isEmpty);
      expect(capacity.replicated, isNotEmpty, reason: 'otherwise this test proves nothing');
    });

    test('leave no oneshot service holding a cpu weight', () {
      final List<String> wrong = <String>[
        for (final ServiceCapacity service in capacity.services)
          if (service.isOneShot && (service.cpuShares != null || service.cpuSharesTotal != null)) service.name,
      ];

      expect(wrong, isEmpty, reason: 'a job that exits straight away disputes nothing with anyone');
    });

    test('give a weight to every service the compose next to them declares', () {
      final List<String> mismatched = <String>[];

      for (final MapEntry<String, CapacitySource> source in capacitySources().entries) {
        if (!source.value.compose.existsSync()) continue;

        final Object? document = loadYaml(source.value.compose.readAsStringSync());
        final Object? services = document is YamlMap ? document['services'] : null;
        final Set<String> declared = <String>{
          if (services is YamlMap)
            for (final Object? name in services.keys) name! as String,
        };

        final Set<String> weighted = <String>{
          if (source.value.weights.existsSync())
            ...Capacity.read(<File>[
              source.value.weights,
            ], const <File>[]).services.map((ServiceCapacity service) => service.name),
        };

        if (declared.difference(weighted).isNotEmpty || weighted.difference(declared).isNotEmpty) {
          mismatched.add('${source.key}: compose $declared, capacity $weighted');
        }
      }

      expect(mismatched, isEmpty, reason: 'a service that ships without a weight takes no share of the machine');
    });

    test('name the profile the compose fragment starts the service under', () {
      final List<String> mismatched = <String>[];

      for (final MapEntry<String, CapacitySource> ops in capacitySources().entries) {
        if (!ops.value.weights.existsSync()) continue;

        final Object? document = loadYaml(ops.value.compose.readAsStringSync());
        final Object? services = document is YamlMap ? document['services'] : null;

        for (final ServiceCapacity service in Capacity.read(<File>[ops.value.weights], const <File>[]).services) {
          final YamlMap? declared = services is YamlMap ? services[service.name] as YamlMap? : null;
          final Object? profiles = declared?['profiles'];
          final String? started = profiles is YamlList && profiles.isNotEmpty ? profiles.first as String : null;

          if (started != service.profile) {
            mismatched.add('${ops.key}/${service.name}: compose $started, capacity ${service.profile}');
          }
        }
      }

      expect(mismatched, isEmpty, reason: 'a service that takes no memory while its profile is off has to say so here');
    });
  });

  group('a weight read against what actually starts', () {
    /// What `config.yaml` gets when it names no optional package that ships a container.
    ///
    /// `foundation` is in it because a project cannot leave it out: it owns the
    /// database, the cache and the queue, which nothing else declares.
    const List<String> defaultSelection = <String>['foundation', 'auth', 'audience'];

    double spentBy(Capacity capacity, Set<String> profiles) => capacity.services
        .where((ServiceCapacity service) => service.startsUnder(profiles))
        .map((ServiceCapacity service) => capacity.shareOf(service.key))
        .reduce((double a, double b) => a + b);

    test('hands out the whole budget, whatever is mounted', () {
      for (final List<String> selection in <List<String>>[
        const <String>[],
        defaultSelection,
        frameworkPackages().keys.toList(),
      ]) {
        final Capacity capacity = frameworkCapacityOf(selection);

        expect(
          spentBy(capacity, packageProfiles),
          closeTo(1, 1e-9),
          reason: 'nothing may be left holding a share of a machine on ${selection.length} package(s)',
        );
      }
    });

    test('grows when a neighbour is left out', () {
      expect(
        frameworkCapacityOf(defaultSelection).shareOf('db'),
        greaterThan(frameworkCapacity().shareOf('db')),
        reason: 'the budget of a package that was dropped goes back to the services that run',
      );
    });

    test('leaves a package the selection dropped unknown', () {
      expect(
        () => frameworkCapacityOf(defaultSelection).shareOf('opensearch'),
        throwsA(isA<ToolExit>()),
        reason: 'a service with no container rendered must not weigh on the calculation',
      );
    });

    test('grows again when a profile is switched off', () {
      final Capacity searching = frameworkCapacityOf(
        <String>[...defaultSelection, 'search'],
        profiles: <String>{'search'},
      );
      final Capacity without = frameworkCapacityOf(<String>[...defaultSelection, 'search'], profiles: <String>{});

      expect(
        without.shareOf('db'),
        greaterThan(searching.shareOf('db')),
        reason: 'opensearch sits behind the search profile, and takes nothing while it is off',
      );
      expect(
        without.shareOf('opensearch'),
        greaterThan(0),
        reason: 'its limit is still written, because the compose document still declares it',
      );
    });

    test('leaves the worker out until the project asks for it', () {
      final Capacity idle = frameworkCapacityOf(defaultSelection, profiles: <String>{});
      final Capacity running = frameworkCapacityOf(defaultSelection, profiles: <String>{'worker'});

      expect(idle.total + idle['worker']!.weight, running.total);
    });
  });
}
