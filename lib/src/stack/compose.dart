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

import 'dart:convert';

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/stack/stack_manifest.dart';

/// The single place `docker compose` is invoked from.
///
/// Every call goes through [StackManifest.arguments], which carries
/// `--project-directory` and `-p`. Neither is a convenience: without the first,
/// every relative path in the documents resolves against the directory holding
/// them rather than the project root, and without the second the verb drives
/// whatever stack the current directory happens to name.
class Compose {
  /// Drives the stack [manifest] describes.
  const Compose(this.manifest);

  /// What was assembled, and how to name it again.
  final StackManifest manifest;

  /// Checks that Compose reads the documents, and returns whether it does.
  ///
  /// This is the last lock of an assembly, and it is not a repeat of the checks
  /// the tool runs itself: the tool reads YAML with Dart and Compose reads it
  /// with go-yaml, the two disagree, and it is Compose that decides what runs.
  /// It needs no daemon, so it costs one exec.
  Future<bool> reads() async {
    final ProcessOutcome outcome = await globals.processRunner.observe(<String>[
      'docker',
      'compose',
      ...manifest.arguments,
      'config',
      '--quiet',
    ]);
    if (outcome.succeeded) return true;

    globals.logger.printError(outcome.stderr.trim());

    return false;
  }

  /// Starts the stack in the background, and returns its status.
  Future<int> up() => _run(<String>['up', '-d', '--remove-orphans']);

  /// Starts the stack and returns once every container has settled, or fails.
  ///
  /// What a deployment needs and a workstation does not: `up -d` returns as
  /// soon as the containers are created, so a deployment that stops there says
  /// it is ready while the database is still opening its files, and whoever
  /// believes it sends the first request into a refusal.
  ///
  /// Compose's own `--wait` is not what does it. It calls any container that
  /// exits a failure, and a stack lays its schema down with two services that
  /// run once and leave, so every deployment would be reported as failed. What
  /// settles a container is read here instead: one that runs is settled once it
  /// is healthy, or straight away when it declares no health check, and one
  /// that ran once is settled by leaving with nothing to say.
  Future<int> upUntilHealthy() async {
    final int status = await up();
    if (status != 0) return status;

    return await _settled() ? 0 : 1;
  }

  Future<bool> _settled() => StackHealth(_containers).settles();

  /// Every container of this stack, as Compose describes it.
  ///
  /// `--all` because a service that ran once and left is no longer listed
  /// otherwise, and a stack whose migration has finished would look like a
  /// stack whose migration never ran.
  Future<String> _containers() async {
    final ProcessOutcome outcome = await globals.processRunner.observe(<String>[
      'docker',
      'compose',
      ...manifest.arguments,
      'ps',
      '--format',
      'json',
      '--all',
    ]);

    return outcome.stdout;
  }

  /// Builds the images this stack declares, and returns its status.
  ///
  /// It is a step of its own rather than `up --build`, because a deployment
  /// builds where the sources are and starts where the host is, and those are
  /// two machines as soon as a target names one.
  Future<int> build() => _run(<String>['build']);

  /// Pushes the images this stack declares to the registry naming them.
  ///
  /// `--include-deps` is left off on purpose: what is pushed is what this stack
  /// builds, and an image it merely pulls belongs to whoever publishes it.
  Future<int> push() => _run(<String>['push']);

  /// Stops the stack and removes what it created, and returns its status.
  ///
  /// [volumes] also removes the named volumes, which is what empties the
  /// database rather than leaving it behind for the next start to adopt.
  Future<int> down({bool volumes = false}) => _run(<String>['down', if (volumes) '--volumes', '--remove-orphans']);

  /// The host port [service] publishes [containerPort] on, or null when none.
  ///
  /// Compose is asked rather than the render, because a workstation lets the
  /// daemon pick the port and the render therefore does not know it. The answer
  /// is `0.0.0.0:49154` or `[::]:49154`, and what a caller needs is the number.
  Future<String?> publishedPortOf(String service, int containerPort) async {
    final String written = await globals.processRunner.capture(<String>[
      'docker',
      'compose',
      ...manifest.arguments,
      'port',
      service,
      '$containerPort',
    ]);

    final int colon = written.trim().lastIndexOf(':');
    if (colon < 0) return null;

    final String port = written.trim().substring(colon + 1);

    return int.tryParse(port) == null ? null : port;
  }

  /// Reads the value of [label] on one container of the stack, or null.
  ///
  /// Returns null when nothing of this stack is up, which is the ordinary case
  /// before a first start and is not an error.
  Future<String?> labelOf(String label) async {
    final String written = await globals.processRunner.capture(<String>[
      'docker',
      'ps',
      '--all',
      '--filter',
      'label=com.docker.compose.project=${manifest.projectName}',
      '--format',
      '{{.Label "$label"}}',
    ]);

    final List<String> lines = <String>[
      for (final String line in written.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];

    return lines.isEmpty ? null : lines.first;
  }

  Future<int> _run(List<String> verb) =>
      globals.processRunner.run(<String>['docker', 'compose', ...manifest.arguments, ...verb]);
}

/// Refuses to drive a stack that another checkout of the same project started.
///
/// Two clones of one project carry the same name in `config.yaml`, and the
/// Docker project name is global to the daemon. So the second `up` silently
/// recreates the first one's containers, mounts its volumes, and a `down` from
/// either stops the other. The label Compose writes on every container is what
/// tells them apart, and it is the only thing that does.
Future<void> refuseForeignCheckout(Compose compose) async {
  final String? running = await compose.labelOf('com.docker.compose.project.working_dir');
  if (running == null || running.isEmpty) return;

  final String mine = compose.manifest.projectDirectory;
  if (globals.fs.path.canonicalize(running) == globals.fs.path.canonicalize(mine)) return;

  throwToolExit(
    '"${compose.manifest.projectName}" is already running from another checkout.\n'
    '  it was started from: $running\n'
    '  this project is at:  $mine\n'
    'Both would write the same services and the same data. Stop the other one first, '
    'or give this project another name in config.yaml.',
  );
}

/// Waits for a stack to settle, wherever the stack runs.
///
/// It is given a way to ask Compose what the containers are doing rather than a
/// way to run Compose, because the same waiting has to work here and over a
/// connection to somebody else's host, and those two differ only in how the
/// question is asked.
class StackHealth {
  /// Waits on the stack [describe] answers for.
  const StackHealth(this.describe);

  /// Asks Compose for `ps --format json --all`, and returns what it wrote.
  final Future<String> Function() describe;

  /// How long the stack has to settle before the start is called off.
  ///
  /// Five minutes, the same bound the provisioning step waits under: the first
  /// start of a stack lays a database down and plays every migration into it,
  /// and a bound that fits the second start would call the first one a failure.
  static const int timeout = 300;

  /// Whether every container settled before [timeout] ran out.
  ///
  /// A container that fails is not waited on: an unhealthy one and one that
  /// left with a status are both final, and holding the deployment open for
  /// five minutes afterwards would only delay the message that says so.
  Future<bool> settles() async {
    final Stopwatch spent = Stopwatch()..start();

    while (spent.elapsed.inSeconds < timeout) {
      final List<Map<String, Object?>> containers = read(await describe());
      final Iterable<Map<String, Object?>> broken = containers.where(hasFailed);

      if (broken.isNotEmpty) {
        for (final Map<String, Object?> container in broken) {
          globals.logger.printError('${container['Service']} ${_stateOf(container)}');
        }

        return false;
      }

      if (containers.isNotEmpty && containers.every(hasSettled)) return true;

      await Future<void>.delayed(const Duration(seconds: 2));
    }

    globals.logger.printError(
      'The stack did not settle within ${timeout}s. '
      'Run docker compose ps to see which container is still trying.',
    );

    return false;
  }

  /// What Compose wrote, one container per line.
  ///
  /// Compose writes a line of JSON per container rather than one array, so a
  /// partial read is a container missing and never a parse error.
  static List<Map<String, Object?>> read(String written) => <Map<String, Object?>>[
    for (final String line in const LineSplitter().convert(written))
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, Object?>,
  ];

  /// Whether this container has finished doing whatever it was going to do.
  ///
  /// One that runs is settled once it is healthy, or straight away when it
  /// declares no health check, and one that ran once is settled by leaving with
  /// nothing to say.
  static bool hasSettled(Map<String, Object?> container) {
    if (container['State'] == 'exited') return container['ExitCode'] == 0;

    return container['State'] == 'running' && (container['Health'] == '' || container['Health'] == 'healthy');
  }

  /// Whether this container will not settle, however long it is given.
  static bool hasFailed(Map<String, Object?> container) =>
      container['Health'] == 'unhealthy' || (container['State'] == 'exited' && container['ExitCode'] != 0);

  static String _stateOf(Map<String, Object?> container) =>
      container['State'] == 'exited' ? 'left with ${container['ExitCode']}' : 'is ${container['Health']}';
}
