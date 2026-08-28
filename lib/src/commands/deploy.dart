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
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/forge.dart';
import 'package:scribe_tools/src/deploy/plan.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/stack/compose.dart';
import 'package:scribe_tools/src/stack/router.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/stack/stack_manifest.dart';
import 'package:scribe_tools/src/tools.dart';

/// Deploys this project onto one of the targets it declares.
///
/// It is not `run --target`, and that is deliberate: `run` is the local loop,
/// it talks to the daemon at hand, and `shutdown` undoes exactly what it did.
/// A deployment creates things that cost money and that stopping a stack does
/// not undo, so it carries a verb of its own.
class DeployCommand extends ScribeCommand {
  /// Declares the target it deploys onto and the three flags around it.
  DeployCommand() {
    argParser
      ..addOption('target', abbr: 't', help: 'The target of configuration/main.yaml this deploys onto.')
      ..addFlag('plan', negatable: false, help: 'Say everything it would do, and write nothing.')
      ..addFlag('yes', abbr: 'y', negatable: false, help: 'Do not ask before creating anything.')
      ..addFlag(
        'worker',
        abbr: 'w',
        negatable: false,
        help: 'Run the project code in a container of its own, and point the API at it.',
      );
  }

  @override
  String get name => 'deploy';

  @override
  String get description => 'Deploy this project onto one of the targets it declares.';

  @override
  bool get requiresCompleteManifest => true;

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String? targetName = stringArg('target');
    if (targetName == null) {
      throwToolExit(_noTarget());
    }

    if (_refuseAnUnforgedProject() case final String refusal) {
      throwToolExit(refusal);
    }

    await generateProjectCode();
    await generateRoutes();

    final ComposeDocuments documents = await ComposeRender(
      project: project,
      withWorker: boolArg('worker'),
      targetName: targetName,
    ).render(await Hardware.detect());

    final DeploymentPlan plan = DeploymentPlan(
      target: ProjectConfiguration.load(project: project).target(targetName),
      resources: documents.resources,
      services: documents.profiles,
    );
    _report(plan);

    if (boolArg('plan')) {
      globals.logger.printStatus('Plan only: nothing was created and nothing was started.');
      return const ScribeCommandResult.success();
    }

    if (plan.blockers.isNotEmpty) {
      for (final String blocker in plan.blockers) {
        globals.logger.printError(blocker);
      }

      return const ScribeCommandResult.fail();
    }

    return _start(plan, documents);
  }

  /// The refusal a project that has not been forged gets, null when it is fine.
  ///
  /// A configuration file that disagrees with what its module declares must not
  /// reach a stack, and least of all a stack somebody else's machine runs.
  String? _refuseAnUnforgedProject() {
    final ForgeReport report = Forge(project: project, packages: Packages.load().active).run(write: false);
    if (report.written.isEmpty && !report.hasProblems) return null;

    return <String>[
      if (report.written.isNotEmpty)
        'These files are missing: ${report.written.map((ForgeEntry e) => '$configurationDirectoryName/${e.name}.yaml').join(', ')}',
      ...report.problems,
      '',
      'scribe forge    writes what is missing and says what is wrong',
    ].join('\n');
  }

  String _noTarget() {
    final List<Target> targets = ProjectConfiguration.load(project: project).targets;

    return <String>[
      'A deployment needs a target, which says where it goes.',
      if (targets.isEmpty)
        'This project declares none. `scribe forge` writes configuration/main.yaml with one.'
      else
        'This project declares: ${targets.map((Target t) => t.name).join(', ')}.',
      '',
      'scribe deploy --target ${targets.isEmpty ? '<name>' : targets.first.name}',
    ].join('\n');
  }

  void _report(DeploymentPlan plan) {
    globals.logger.printStatus('');
    globals.logger.printStatus(
      '  ${plan.target.name}  ${plan.target.kind.name}'
      '${plan.target.host.isEmpty ? '' : '  ${plan.target.host}'}',
    );
    globals.logger.printStatus('');

    for (final ResolvedResource resource in plan.resources.resolved) {
      globals.logger.printStatus('  ${resource.resource.name.padRight(12)}${resource.className}');
    }

    globals.logger.printStatus('');
    globals.logger.printStatus(
      '${plan.inContainers.length} in containers, ${plan.alreadyThere.length} already there, '
      '${plan.provisioned.length} to create',
    );
  }

  Future<ScribeCommandResult> _start(DeploymentPlan plan, ComposeDocuments documents) async {
    final StackLocation location = StackLocation(project: project);
    final StackManifest manifest = StackManifest(
      projectDirectory: documents.projectDirectory,
      projectName: documents.projectName,
      files: <String>[for (final File file in documents.files) file.absolute.path],
      profiles: documents.profiles,
    )..write(location.manifest);

    final Compose compose = Compose(manifest);
    if (!await compose.reads()) {
      throwToolExit(
        'The assembled project does not hold together. It is left in ${location.directory.path} to be read.',
      );
    }

    const Router router = Router();
    if (!await router.ensureUp()) {
      throwToolExit('The router of this machine did not start, so nothing would be reachable.');
    }

    if (await compose.up() != 0) return const ScribeCommandResult.fail();

    await router.attach('${manifest.projectName}_edge');
    globals.logger.printStatus('ready  ${plan.target.domain.isEmpty ? documents.hostnames.first : plan.target.domain}');

    return const ScribeCommandResult.success();
  }
}
