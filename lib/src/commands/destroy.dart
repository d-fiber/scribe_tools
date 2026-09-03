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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/deploy/drivers/ssh.dart';
import 'package:scribe_tools/src/deploy/tofu.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/configuration.dart';
import 'package:scribe_tools/src/ops/resources.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/tools.dart';

/// Takes a deployment down, and removes what it created.
///
/// It carries a verb of its own rather than a flag on `deploy`, because a flag
/// that deletes a database is a flag somebody passes by accident. What it is
/// going to remove is named before it removes anything, and nothing is removed
/// without an answer.
class DestroyCommand extends ScribeCommand {
  /// Declares the target it takes down, and what it is allowed to take with it.
  DestroyCommand() {
    argParser
      ..addOption('target', abbr: 't', help: 'The target of configuration/main.yaml this takes down.')
      ..addFlag(
        'data',
        negatable: false,
        help: 'Also remove the volumes, which is what empties the database rather than leaving it.',
      )
      ..addFlag('yes', abbr: 'y', negatable: false, help: 'Do not ask, which is what a script needs.');
  }

  @override
  String get name => 'destroy';

  @override
  String get description => 'Take a deployment down, and remove what it created.';

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String? targetName = stringArg('target');
    if (targetName == null) {
      throwToolExit('A destruction needs a target, which says what comes down.');
    }

    final ProjectConfiguration configuration = ProjectConfiguration.load(project: project);
    final Target target = configuration.target(targetName);
    final List<Resource> provisioned = _provisionedOn(configuration, target);

    if (!_agreed(target, provisioned)) {
      globals.logger.printStatus('Nothing was removed. Pass --yes to remove what is listed above.');

      return const ScribeCommandResult.success();
    }

    if (!await _takeTheStackDown(target)) return const ScribeCommandResult.fail();

    for (final Resource resource in provisioned) {
      globals.tools.require(ToolCatalog.tofu, reason: '${resource.name} was created by it');

      globals.logger.printStatus('Destroying ${resource.name}...');
      if (!await Tofu(_stateOf(target, resource)).destroy()) return const ScribeCommandResult.fail();
    }

    globals.logger.printStatus('${target.name} is down.');

    return const ScribeCommandResult.success();
  }

  /// The resources of this project a recipe created on [target].
  ///
  /// A resource in a container comes down with the stack, and one that was
  /// already there was never ours to remove: only what a recipe made is
  /// destroyed, and only where its state says it exists.
  List<Resource> _provisionedOn(ProjectConfiguration configuration, Target target) => <Resource>[
    for (final Resource resource in Resources.declared())
      if (!configuration.placementOf(target.name, resource.name).isContainer &&
          !configuration.placementOf(target.name, resource.name).isExternal)
        if (_stateOf(target, resource).existsSync()) resource,
  ];

  /// Names everything that is about to go, and answers whether it may.
  ///
  /// The list is printed rather than a count: somebody agreeing to "3 resources"
  /// has agreed to nothing they could picture. Nothing is removed without
  /// `--yes`, which a person types after reading the list and a script carries.
  bool _agreed(Target target, List<Resource> provisioned) {
    globals.logger.printStatus('');
    globals.logger.printStatus('This removes, on ${target.name}:');
    globals.logger.printStatus('  the containers of the stack${target.host.isEmpty ? '' : ' on ${target.host}'}');
    if (target.host.isNotEmpty) {
      globals.logger.printStatus('  the documents this deployment shipped to ${target.host}');
    }
    if (boolArg('data')) {
      globals.logger.printStatus('  their volumes, and the data in them');
    }
    for (final Resource resource in provisioned) {
      globals.logger.printStatus('  ${resource.name}, a ${resource.type} a recipe created');
    }
    globals.logger.printStatus('');

    return boolArg('yes');
  }

  Future<bool> _takeTheStackDown(Target target) async {
    final StackLocation location = StackLocation(project: project);
    final List<String> arguments = <String>['down', '--remove-orphans', if (boolArg('data')) '--volumes'];

    if (target.host.isEmpty) {
      final Directory stack = location.directory;
      if (!stack.existsSync()) return true;

      DockerComposeCmd command = DockerCompose.arg(
        '--project-directory',
      ).arg(project.directory.absolute.path).arg('-p').arg(project.manifest.name);
      for (final File document in stack.listSync().whereType<File>()) {
        if (document.path.endsWith('.yaml')) command = command.arg('-f').arg(document.path);
      }
      command = command.down().removeOrphans();
      if (boolArg('data')) command = command.removeVolumes();

      return await globals.processRunner.run(commandArgv(command)) == 0;
    }

    final RemoteHost host = RemoteHost(target.host);
    final String? home = await host.home();
    if (home == null) return false;

    final String root = '$home/.scribe_cache/stacks/${location.fingerprint}';
    final int status = await host.compose(
      arguments,
      root: root,
      projectName: project.manifest.name,
      documents: const <String>[],
    );
    if (status != 0) return false;

    // The stack this deployment shipped goes with it: a directory of documents
    // left on a host is a deployment somebody can start again by hand, months
    // after the project stopped describing it.
    return host.remove(root);
  }

  Directory _stateOf(Target target, Resource resource) => project.directory
      .childDirectory('.scribe')
      .childDirectory('state')
      .childDirectory(target.name)
      .childDirectory(resource.name);
}
