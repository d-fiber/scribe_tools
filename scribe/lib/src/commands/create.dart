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
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/commands/create/create_report.dart';
import 'package:scribe/src/commands/create/project_scaffold.dart';
import 'package:scribe/src/commands/create/sdk_choice.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project_templates.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/runner/scribe_command_runner.dart';
import 'package:scribe/src/sdk_target.dart';

/// Scaffolds a project in `./<name>`, and nothing else.
///
/// No repository is initialised and no generator is run: what this writes is
/// what the templates hold.
class CreateCommand extends ScribeCommand {
  CreateCommand() {
    argParser.addOption(
      sdkOption,
      abbr: 's',
      valueHelp: 'name',
      help:
          'The SDK the endpoints are written against${_sdksOnDisk()}. '
          'The choices are the directories of scribe/sdk/, so they follow the framework. '
          'Asked interactively when left out.',
    );
  }

  /// The option that settles the SDK without asking.
  static const String sdkOption = 'sdk';

  /// What a project may be called.
  ///
  /// The name becomes three things at once — the directory, the derived
  /// directory `.<name>/` and the import alias `@<name>/` — so anything that
  /// cannot sit in an import specifier cannot name a project.
  static final RegExp _acceptedName = RegExp(r'^[a-z][a-z0-9_-]*$');

  /// What the missing `<name>` is, printed above the usage when it is left out.
  ///
  /// It says the one thing the usage below it cannot: what the name becomes.
  /// Everything else — where the project lands, what `--sdk` does — is in the
  /// usage already, and saying it twice makes two messages out of one.
  static final String _nameExplained =
      'It is the name of the project, and it becomes three things at once: the directory '
      './<name>, the generated directory ".<name>/" and the import alias "@<name>/". Lowercase '
      'letters, digits, "-" and "_", starting with a letter.\n'
      '\n'
      '  scribe create my_app\n'
      '  scribe create my_app --sdk ${sdkSpelling(kDefaultSdkName)}';

  final CreateReport _report = const CreateReport();

  /// The SDKs of the framework next to the caller, as the option's help names them.
  ///
  /// Empty when there is no framework above the current directory, which is
  /// what `--sdk` on a machine without a checkout has to read like.
  ///
  /// Only the names of the directories are read, never what they hold: this
  /// runs when the command is built, and a command is built on every `scribe`
  /// invocation, `gen` included.
  static String _sdksOnDisk() {
    final Directory? framework = SdkCatalog.findFrameworkRoot(globals.fs.currentDirectory);
    final Directory? sdks = framework?.childDirectory('sdk');
    if (sdks == null || !sdks.existsSync()) return '';

    final List<String> names =
        sdks
            .listSync(followLinks: false)
            .whereType<Directory>()
            .map((Directory entry) => entry.basename)
            .where(kKnownSdks.containsKey)
            .map(sdkSpelling)
            .toList()
          ..sort();

    return names.isEmpty ? '' : ', one of ${names.join(', ')}';
  }

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
    final SdkChoice choice = SdkChoice(
      catalog: SdkCatalog.discover(from: globals.fs.currentDirectory),
      commandName: name,
      assumeYes: ScribeCommandRunner.assumesYes(globalResults),
    );

    final String projectName = requirePositional(
      'name',
      explain: _nameExplained,
      alsoWrong: choice.unknownSdk(stringArg(sdkOption)),
    );
    final Directory root = _destinationFor(projectName);
    final ProjectTemplates templates = _templates();

    final SdkTarget target = await choice.resolve(stringArg(sdkOption));

    final ProjectScaffold scaffold = ProjectScaffold(
      root: root,
      name: projectName,
      target: target,
      templates: templates,
    );
    await _write(scaffold, projectName: projectName, target: target);

    _report.wrote(scaffold.files);
    _report.caveats(target, templates);
    _report.nextStep(projectName, target);

    return const ScribeCommandResult.success();
  }

  /// The directory the project is written into.
  ///
  /// Throws a [ToolExit] when [projectName] cannot name one, or when something
  /// is already there — nothing is ever merged into an existing directory.
  Directory _destinationFor(String projectName) {
    if (!_acceptedName.hasMatch(projectName)) {
      throwToolExit(
        '"$projectName" cannot name a project. Use lowercase letters, digits, "-" and "_", '
        'starting with a letter: the name becomes the folder, the generated directory '
        '".$projectName/" and the import alias "@$projectName/".',
      );
    }

    final Directory root = globals.fs.currentDirectory.childDirectory(projectName);
    if (root.existsSync()) {
      throwToolExit('${root.path} already exists. Pick another name, or remove it first.');
    }

    return root;
  }

  /// The templates of the framework above the current directory.
  ///
  /// Throws a [ToolExit] when there is none. A project without the framework
  /// would not run anyway, so this refuses rather than writing half of one.
  ProjectTemplates _templates() {
    final ProjectTemplates? found = ProjectTemplates.find(
      SdkCatalog.findFrameworkRoot(globals.fs.currentDirectory),
    );
    if (found != null) return found;

    throwToolExit(
      'The project templates live in <scribe>/$kTemplatesDirectoryName/, and there is no scribe '
      'checkout above ${globals.fs.currentDirectory.path}.\n'
      'Run this from inside a checkout, or next to one.',
    );
  }

  Future<void> _write(ProjectScaffold scaffold, {required String projectName, required SdkTarget target}) async {
    final Status status = globals.logger.startProgress('Creating $projectName on the ${target.label} SDK');

    try {
      await scaffold.write();
    } finally {
      status.stop();
    }
  }
}
