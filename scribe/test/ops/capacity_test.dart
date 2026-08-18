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
import 'package:scribe/src/ops/capacity.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'capacity_source.dart';

/// What a service's memory and cores may be translated into.
///
/// Closed on purpose: a module declares what it is, not how it is tuned, so a
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

    test('agree with the ops block of the manifest next to them', () {
      final List<String> mismatched = <String>[];

      for (final MapEntry<String, Directory> module in frameworkModules().entries) {
        final YamlMap manifest =
            loadYaml(module.value.childFile('scribe.yaml').readAsStringSync()) as YamlMap;
        final Object? ops = manifest['ops'];
        final Set<String> announced = <String>{
          if (ops is YamlMap && ops['services'] is YamlList)
            for (final Object? name in ops['services'] as YamlList) name! as String,
        };

        final Set<String> weighted = <String>{
          for (final Directory ops in opsDirectories(module.value))
            if (ops.childFile(capacityFileName).existsSync())
              ...Capacity.read(ops, const <File>[]).services.map((ServiceCapacity service) => service.name),
        };

        if (announced.difference(weighted).isNotEmpty || weighted.difference(announced).isNotEmpty) {
          mismatched.add('${module.key}: manifest $announced, capacity $weighted');
        }
      }

      expect(mismatched, isEmpty, reason: 'a service added to the manifest has to be given a weight');
    });

    test('name the profile the compose fragment starts the service under', () {
      final List<String> mismatched = <String>[];

      for (final MapEntry<String, CapacitySource> ops in capacitySources().entries) {
        if (!ops.value.weights.childFile(capacityFileName).existsSync()) continue;

        final Object? document = loadYaml(ops.value.compose.readAsStringSync());
        final Object? services = document is YamlMap ? document['services'] : null;

        for (final ServiceCapacity service in Capacity.read(ops.value.weights, const <File>[]).services) {
          final YamlMap? declared = services is YamlMap ? services[service.name] as YamlMap? : null;
          final Object? profiles = declared?['profiles'];
          final String? started = profiles is YamlList && profiles.isNotEmpty ? profiles.first as String : null;

          if (started != service.profile) {
            mismatched.add('${ops.key}/${service.name}: compose $started, capacity ${service.profile}');
          }
        }
      }

      expect(
        mismatched,
        isEmpty,
        reason: 'a service that takes no memory while its profile is off has to say so here',
      );
    });
  });

  group('a weight read against what actually starts', () {
    /// What `config.yaml` gets when it names no optional module.
    const List<String> defaultSelection = <String>['security/auth', 'security/rbac'];

    double spentBy(Capacity capacity, Set<String> profiles) => capacity.services
        .where((ServiceCapacity service) => service.startsUnder(profiles))
        .map((ServiceCapacity service) => capacity.shareOf(service.key))
        .reduce((double a, double b) => a + b);

    test('hands out the whole budget, whatever is mounted', () {
      for (final List<String> selection in <List<String>>[
        const <String>[],
        defaultSelection,
        frameworkModules().keys.toList(),
      ]) {
        final Capacity capacity = frameworkCapacityOf(selection);

        expect(
          spentBy(capacity, moduleProfiles),
          closeTo(1, 1e-9),
          reason: 'nothing may be left holding a share of a machine on ${selection.length} module(s)',
        );
      }
    });

    test('grows when a neighbour is left out', () {
      expect(
        frameworkCapacityOf(defaultSelection).shareOf('db'),
        greaterThan(frameworkCapacity().shareOf('db')),
        reason: 'the budget of a module that was dropped goes back to the services that run',
      );
    });

    test('leaves a module the selection dropped unknown', () {
      expect(
        () => frameworkCapacityOf(defaultSelection).shareOf('opensearch'),
        throwsA(isA<ToolExit>()),
        reason: 'a service with no container rendered must not weigh on the calculation',
      );
    });

    test('grows again when a profile is switched off', () {
      final Capacity withStudio = frameworkCapacityOf(defaultSelection, profiles: <String>{'ops'});
      final Capacity without = frameworkCapacityOf(defaultSelection, profiles: <String>{});

      expect(
        without.shareOf('db'),
        greaterThan(withStudio.shareOf('db')),
        reason: 'studio sits behind the ops profile, and takes nothing while it is off',
      );
      expect(
        without.shareOf('studio'),
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
