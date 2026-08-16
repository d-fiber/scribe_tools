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
import 'package:interact/interact.dart' as interact;
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/commands/create/project_scaffold.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/project_templates.dart';
import 'package:scribe/src/runner/scribe_command_runner.dart';
import 'package:scribe/src/sdk_target.dart';

class CreateCommand extends ScribeCommand {
  CreateCommand() {
    argParser.addOption(
      sdkOption,
      abbr: 's',
      valueHelp: 'name',
      help: 'The SDK the endpoints are written against. '
          'The choices are the directories of scribe/sdk/, so they follow the framework. '
          'Asked interactively when left out.',
    );
  }

  static const String sdkOption = 'sdk';

  static final RegExp _acceptedName = RegExp(r'^[a-z][a-z0-9_-]*$');

  @override
  String get name => 'create';

  @override
  String get description => 'Scaffold a project in ./<name>.';

  @override
  String get invocation => 'scribe create <name> [--sdk <name>]';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String projectName = requirePositional('name');
    _rejectUnusableName(projectName);

    final Directory root = globals.fs.currentDirectory.childDirectory(projectName);
    if (root.existsSync()) {
      throwToolExit('${root.path} already exists. Pick another name, or remove it first.');
    }

    final Directory? framework = SdkCatalog.findFrameworkRoot(globals.fs.currentDirectory);
    final SdkCatalog catalog = SdkCatalog.discover(from: globals.fs.currentDirectory);
    final ProjectTemplates? templates = ProjectTemplates.find(framework);

    if (templates == null) {
      throwToolExit(
        'The project templates live in <scribe>/$kTemplatesDirectoryName/, and there is no scribe '
        'checkout above ${globals.fs.currentDirectory.path}.\n'
        'Run this from inside a checkout, or next to one.',
      );
    }

    final SdkTarget target = await _resolveTarget(catalog, templates);

    final ProjectScaffold scaffold = ProjectScaffold(
      root: root,
      name: projectName,
      target: target,
      templates: templates,
    );
    final Status status = globals.logger.startProgress('Creating $projectName on the ${target.name} SDK');

    try {
      await scaffold.write();
    } finally {
      status.stop();
    }

    globals.logger.printStatus('');
    for (final String file in scaffold.files) {
      globals.logger.printStatus('  $file');
    }
    globals.logger.printStatus('');

    _warnAbout(target, templates);

    globals.logger.printStatus(
      'Next: cd $projectName, fill config.yaml, then run `scribe gen routes`.',
      emphasis: true,
    );

    return const ScribeCommandResult.success();
  }

  Future<SdkTarget> _resolveTarget(SdkCatalog catalog, ProjectTemplates templates) async {
    final String? asked = stringArg(sdkOption);

    if (asked != null) return _named(asked, catalog);
    if (!catalog.isKnown) return _assumeDefault('no scribe checkout above this directory');

    final List<SdkTarget> choices = catalog.offerable;
    _reportIgnored(catalog);

    if (choices.isEmpty) return _assumeDefault('${catalog.root!.path} holds no usable SDK');
    if (choices.length == 1) {
      globals.logger.printStatus('Only one SDK is available, ${choices.single.name}.');
      return choices.single;
    }

    final bool canAsk = globals.terminal.supportsRawInput && !ScribeCommandRunner.assumesYes(globalResults);
    if (!canAsk) return _assumeDefault('nothing to ask on', choices: choices);

    return _ask(choices);
  }

  SdkTarget _named(String asked, SdkCatalog catalog) {
    if (!catalog.isKnown) return SdkTarget.assumed(asked.trim().toLowerCase());

    final SdkTarget? found = catalog.byName(asked);
    if (found == null) {
      throwUsageError(
        '"$asked" is not an SDK this framework carries. '
        'The choices come from ${catalog.root!.path}: ${catalog.names.join(', ')}.',
        command: name,
      );
    }
    if (!found.isRecognised || found.isEmpty) {
      throwToolExit('${found.caveat}\nPick another SDK: ${catalog.names.join(', ')}.');
    }

    return found;
  }

  void _reportIgnored(SdkCatalog catalog) {
    for (final SdkTarget target in catalog.ignored) {
      globals.logger.printTrace('skipping sdk/${target.name}: ${target.caveat}');
    }
  }

  SdkTarget _assumeDefault(String why, {List<SdkTarget> choices = const <SdkTarget>[]}) {
    for (final SdkTarget candidate in choices) {
      if (candidate.name == kDefaultSdkName) {
        globals.logger.printStatus('Using the $kDefaultSdkName SDK: $why to pick another.');
        return candidate;
      }
    }

    globals.logger.printStatus('Using the $kDefaultSdkName SDK: $why to pick another.');
    return const SdkTarget.assumed(kDefaultSdkName);
  }

  Future<SdkTarget> _ask(List<SdkTarget> choices) async {
    final int defaultIndex = choices.indexWhere((SdkTarget target) => target.name == kDefaultSdkName);

    final int picked = interact.Select(
      prompt: 'Which SDK will the endpoints be written against?',
      options: <String>[for (final SdkTarget target in choices) target.label],
      initialIndex: defaultIndex < 0 ? 0 : defaultIndex,
    ).interact();

    return choices[picked];
  }

  void _warnAbout(SdkTarget target, ProjectTemplates templates) {
    if (!templates.has(target.name)) {
      globals.logger.printWarning(
        'There is no template for the ${target.name} SDK in ${templates.path}, so only the files '
        'shared by every project were written. Add ${target.name}/ next to common/ to fix that.',
      );
      globals.logger.printStatus('');
    }

    final String? caveat = target.caveat;
    if (caveat == null) return;

    globals.logger.printWarning('The ${target.name} SDK is not usable yet: $caveat');
    globals.logger.printStatus('');
  }

  void _rejectUnusableName(String projectName) {
    if (_acceptedName.hasMatch(projectName)) return;

    throwToolExit(
      '"$projectName" cannot name a project. Use lowercase letters, digits, "-" and "_", '
      'starting with a letter: the name becomes the folder, the generated directory '
      '".$projectName/" and the import alias "@$projectName/".',
    );
  }
}
