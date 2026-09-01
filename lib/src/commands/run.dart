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
import 'package:scribe_tools/src/commands/gen/code/generate.dart';
import 'package:scribe_tools/src/commands/gen/routes/routes_command.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:scribe_tools/src/stack/compose.dart';
import 'package:scribe_tools/src/stack/router.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/stack/stack_manifest.dart';
import 'package:scribe_tools/src/tools.dart';

/// Assembles this project into a stack and runs it.
///
/// It is the command the tool never had: the renderer existed, was complete and
/// tested, and its only caller in the whole repository was a test. Nothing
/// invoked Docker, so nothing checked that what the renderer produced could be
/// read, mounted, or started.
class RunCommand extends ScribeCommand {
  /// Declares the four options that decide what is started.
  RunCommand() {
    argParser
      ..addFlag(
        'worker',
        abbr: 'w',
        negatable: false,
        help: 'Run the project code in a container of its own, and point the API at it.',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Render for a target config.yaml declares, instead of the machine this runs on.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Assemble the project and check it, without starting anything.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Start even when another checkout of this project is already running.',
      )
      ..addFlag(
        ScribeCommand.watchOption,
        negatable: false,
        help:
            'Restart the api, and the worker with --worker, every time lib/ changes. '
            'A change under configuration/ or config.yaml needs a fresh scribe run instead.',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description => 'Run this project: its API, and everything it depends on.';

  @override
  bool get requiresCompleteManifest => true;

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    await generateProjectCode();
    await generateRoutes();

    final ComposeDocuments documents = await ComposeRender(
      project: project,
      withWorker: boolArg('worker'),
      targetName: stringArg('target'),
    ).render(await Hardware.detect());
    final StackLocation location = StackLocation(project: project);

    final StackManifest manifest = StackManifest(
      projectDirectory: documents.projectDirectory,
      projectName: documents.projectName,
      files: <String>[for (final File file in documents.files) file.absolute.path],
      profiles: documents.profiles,
    )..write(location.manifest);

    globals.logger.printStatus('Assembled ${manifest.projectName} in ${location.directory.path}');

    final Compose compose = Compose(manifest);
    if (!await compose.reads()) {
      throwToolExit(
        'The assembled project does not hold together. It is left in ${location.directory.path} to be read.',
      );
    }

    if (boolArg('dry-run')) {
      globals.logger.printStatus('Dry run: assembled and checked, nothing was started.');
      return const ScribeCommandResult.success();
    }

    if (boolArg(ScribeCommand.watchOption) && documents.kind != TargetKind.dev) {
      throwUsageError(
        '--watch restarts containers on this workstation, and the target given deploys elsewhere. '
        'Run without --target for that, or without --watch to deploy once.',
        command: invocationName,
      );
    }

    if (!boolArg('force')) await refuseForeignCheckout(compose);

    if (documents.kind == TargetKind.dev) {
      final ScribeCommandResult started = await _startOnThisWorkstation(compose, manifest.projectName);
      if (started.exitStatus != ExitStatus.success || !boolArg(ScribeCommand.watchOption)) return started;

      return watchAndRerun(<FileSystemEntity>[project.lib], () => _restart(compose));
    }

    const Router router = Router();
    if (!await router.ensureUp()) {
      throwToolExit('The router of this machine did not start, so nothing would be reachable.');
    }

    final List<String> taken = await router.hostnamesTakenBesides(manifest.projectName);
    final List<String> clashing = documents.hostnames.where(taken.contains).toList();
    if (clashing.isNotEmpty) {
      throwToolExit(
        'Another project on this machine already answers on ${clashing.join(', ')}.\n'
        'Two projects cannot share a hostname: rename this one in config.yaml, or stop the other.',
      );
    }

    globals.logger.printStatus('Starting ${manifest.projectName}...');

    if (await compose.up() != 0) {
      return const ScribeCommandResult.fail();
    }

    await router.attach('${manifest.projectName}_edge');
    globals.logger.printStatus('It answers on http://${documents.hostnames.first}');

    return const ScribeCommandResult.success();
  }

  /// Starts the stack on the workstation this command runs on.
  ///
  /// No router and no hostname: a workstation has neither, and putting one there
  /// would take port 80 from whatever already holds it. The proxy publishes a
  /// port the daemon picks instead, so a second project started a minute later
  /// gets another one rather than a refusal.
  Future<ScribeCommandResult> _startOnThisWorkstation(Compose compose, String projectName) async {
    globals.logger.printStatus('Starting $projectName on this workstation...');

    if (await compose.up() != 0) return const ScribeCommandResult.fail();

    final String? port = await compose.publishedPortOf('caddy', 80);
    if (port == null) {
      globals.logger.printWarning('The stack is up, but no published port was found to reach it on.');
      return const ScribeCommandResult.success();
    }

    globals.logger.printStatus('It answers on http://localhost:$port');

    return const ScribeCommandResult.success();
  }

  /// Regenerates what a change under `lib/` can affect, then restarts the api
  /// and, with `--worker`, the worker: the two containers `--watch` may need
  /// to reach code it just changed.
  ///
  /// A container is restarted rather than recreated because nothing about the
  /// stack itself changed, only the files it already mounts. `compose up`
  /// would see the same configuration it started with and do nothing.
  Future<ScribeCommandResult> _restart(Compose compose) async {
    await generateProjectCode();
    await generateRoutes();

    final List<String> services = <String>['api', if (boolArg('worker')) 'worker'];
    globals.logger.printStatus('Restarting ${services.join(', ')}...');

    return await compose.restart(services) == 0
        ? const ScribeCommandResult.success()
        : const ScribeCommandResult.fail();
  }
}
