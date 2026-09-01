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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/drivers/ssh.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/tools.dart';

/// Says what a target is running, without assembling anything.
///
/// It reads the deployment rather than the project: what a stack was rendered
/// from can have changed a dozen times since it started, and the question this
/// answers is what is up now.
class StatusCommand extends ScribeCommand {
  /// Declares the target it reads.
  StatusCommand() {
    argParser
      ..addOption('target', abbr: 't', help: 'The target of configuration/main.yaml this reads.')
      ..addFlag(
        ScribeCommand.machineOption,
        negatable: false,
        help: 'Print one line of JSON instead of a report a person reads.',
      );
  }

  @override
  String get name => 'status';

  @override
  String get description => 'Say what a target is running, and where each resource of it lives.';

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String? targetName = stringArg('target');
    if (targetName == null) {
      throwToolExit('A status needs a target, which says where to look.');
    }

    final ProjectConfiguration configuration = ProjectConfiguration.load(project: project);
    final Target target = configuration.target(targetName);
    final bool machine = boolArg(ScribeCommand.machineOption);

    if (!machine) {
      globals.logger.printStatus('');
      globals.logger.printStatus(
        '  ${target.name}  ${target.kind.name}${target.host.isEmpty ? '' : '  ${target.host}'}',
      );
      globals.logger.printStatus('');
      _reportPlacements(configuration, target);
    }

    final String? services = await _servicesOf(target);
    if (services == null) {
      if (machine) printMachine(_machineReport(configuration, target, services: const <ServiceStatus>[], ok: false));
      return const ScribeCommandResult.fail();
    }

    final List<ServiceStatus> parsed = _parseServices(services);

    if (machine) {
      printMachine(_machineReport(configuration, target, services: parsed, ok: true));
      return const ScribeCommandResult.success();
    }

    globals.logger.printStatus('');
    if (parsed.isEmpty) {
      globals.logger.printStatus('Nothing is running. `scribe deploy --target ${target.name}` starts it.');

      return const ScribeCommandResult.success();
    }

    for (final ServiceStatus service in parsed) {
      globals.logger.printStatus('  ${service.service}\t${service.state}\t${service.health}');
    }

    return const ScribeCommandResult.success();
  }

  Map<String, Object?> _machineReport(
    ProjectConfiguration configuration,
    Target target, {
    required List<ServiceStatus> services,
    required bool ok,
  }) => <String, Object?>{
    'command': 'status',
    'ok': ok,
    'target': <String, Object?>{'name': target.name, 'kind': target.kind.name, 'host': target.host},
    'placements': <Object?>[
      for (final Resource resource in Resources.declared())
        <String, Object?>{
          'resource': resource.name,
          'recipe': configuration.placementOf(target.name, resource.name).recipeName,
        },
    ],
    'services': <Object?>[for (final ServiceStatus service in services) service.toJson()],
  };

  /// Where each resource of this project sits on [target].
  ///
  /// It is read from the configuration and not from the host: a resource placed
  /// elsewhere has no container to be seen, and its absence from a list of
  /// containers would read as a stack that is half down.
  void _reportPlacements(ProjectConfiguration configuration, Target target) {
    for (final Resource resource in Resources.declared()) {
      final Placement placement = configuration.placementOf(target.name, resource.name);
      globals.logger.printStatus('  ${resource.name.padRight(12)}${placement.recipeName}');
    }
  }

  /// What Compose says is up, on this machine or on the host.
  Future<String?> _servicesOf(Target target) async {
    const List<String> arguments = <String>['ps', '--format', '{{.Service}}\t{{.State}}\t{{.Health}}'];

    if (target.host.isEmpty) {
      final ProcessOutcome outcome = await globals.processRunner.observe(<String>[
        'docker',
        'compose',
        '-p',
        project.manifest.name,
        ...arguments,
      ]);

      return outcome.succeeded ? outcome.stdout : _refuse(outcome);
    }

    final RemoteHost host = RemoteHost(target.host);
    final String? home = await host.home();
    if (home == null) return null;

    final ProcessOutcome outcome = await globals.processRunner.observe(<String>[
      'ssh',
      target.host,
      <String>[
        'docker',
        'compose',
        '--project-directory',
        '$home/.scribe_cache/stacks/${StackLocation(project: project).fingerprint}',
        '-p',
        project.manifest.name,
        ...arguments,
      ].join(' '),
    ]);

    return outcome.succeeded ? outcome.stdout : _refuse(outcome);
  }

  String? _refuse(ProcessOutcome outcome) {
    globals.logger.printError(outcome.stderr.trim());

    return null;
  }
}

/// [raw], the tab-separated lines `--format` above asked `docker compose ps` for, one [ServiceStatus] each.
List<ServiceStatus> _parseServices(String raw) => <ServiceStatus>[
  for (final String line in raw.trim().split('\n'))
    if (line.trim().isNotEmpty) ServiceStatus.parse(line),
];

/// One service `docker compose ps` reported, its state and its health.
class ServiceStatus {
  /// Records what was read for [service].
  const ServiceStatus({required this.service, required this.state, required this.health});

  /// Reads a `service\tstate\thealth` line, the shape `--format` above asked for.
  factory ServiceStatus.parse(String line) {
    final List<String> columns = line.split('\t');
    return ServiceStatus(
      service: columns.isNotEmpty ? columns[0] : '',
      state: columns.length > 1 ? columns[1] : '',
      health: columns.length > 2 ? columns[2] : '',
    );
  }

  /// The name of the service, as the compose file names it.
  final String service;

  /// What `docker compose ps` reports it is doing.
  final String state;

  /// The health check's own verdict, empty when the service declares none.
  final String health;

  /// This service, in the shape `--machine` prints.
  Map<String, Object?> toJson() => <String, Object?>{'service': service, 'state': state, 'health': health};
}
