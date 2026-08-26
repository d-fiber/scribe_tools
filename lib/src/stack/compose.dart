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

  /// Stops the stack and removes what it created, and returns its status.
  ///
  /// [volumes] also removes the named volumes, which is what empties the
  /// database rather than leaving it behind for the next start to adopt.
  Future<int> down({bool volumes = false}) => _run(<String>['down', if (volumes) '--volumes', '--remove-orphans']);

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
