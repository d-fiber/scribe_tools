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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/commands/create/create_report.dart';
import 'package:scribe_tools/src/commands/create/project_scaffold.dart';
import 'package:scribe_tools/src/commands/create/sdk_choice.dart';
import 'package:scribe_tools/src/deploy/forge.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/project_templates.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/runner/scribe_command_runner.dart';
import 'package:scribe_tools/src/sdk_target.dart';
import 'package:scribe_tools/src/templates.dart';

/// Scaffolds a project in `./<name>`, and nothing else.
///
/// No repository is initialised and no generator is run: what this writes is
/// what the templates hold.
class CreateCommand extends ScribeCommand {
  /// Declares `--sdk`, whose help lists the SDKs the framework on disk carries.
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
  /// The name becomes three things at once: the directory, the derived
  /// directory `.<name>/` and the import alias `@<name>/`. Anything that cannot
  /// sit in an import specifier therefore cannot name a project.
  static final RegExp _acceptedName = RegExp(r'^[a-z][a-z0-9_-]*$');

  /// What the missing `<name>` is, printed above the usage when it is left out.
  ///
  /// It says the one thing the usage below it cannot: what the name becomes.
  /// Everything else is in the usage already, from where the project lands to
  /// what `--sdk` does, and saying it twice makes two messages out of one.
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
    _requireFramework();

    final Directory root = _destinationFor(projectName);
    final ProjectTemplates templates = _templates();

    final SdkTarget target = await choice.resolve(stringArg(sdkOption));

    final ProjectScaffold scaffold = ProjectScaffold(
      root: root,
      name: projectName,
      target: target,
      templates: templates,
      scribeVersion: findSdk(from: globals.fs.currentDirectory.path).version,
    );
    await _write(scaffold, projectName: projectName, target: target);
    await _forge(root);

    _report
      ..wrote(scaffold.files)
      ..caveats(target, templates)
      ..nextStep(projectName, target);

    return const ScribeCommandResult.success();
  }

  /// The directory the project is written into.
  ///
  /// Throws a [ToolExit] when [projectName] cannot name one, or when something
  /// is already there, since nothing is ever merged into an existing directory.
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

  /// Refuses when no framework sits above the current directory.
  ///
  /// The templates no longer come from the checkout, so nothing else would stop
  /// a scaffold here. It still has to stop: what is written imports the SDK
  /// through a relative path into `scribe/`, and a project written next to
  /// nothing would not run.
  void _requireFramework() {
    if (SdkCatalog.findFrameworkRoot(globals.fs.currentDirectory) != null) return;

    throwToolExit(
      'A project reads the SDK out of the framework next to it, and there is no scribe '
      'checkout above ${globals.fs.currentDirectory.path}.\n'
      'Run this from inside a checkout, or next to one.',
    );
  }

  /// The templates this tool ships.
  ///
  /// Throws a [ToolExit] when they are not there. An installation missing them
  /// cannot scaffold anything, so this refuses rather than writing half a project.
  ProjectTemplates _templates() {
    final ProjectTemplates? found = ProjectTemplates.find();
    if (found != null) return found;

    throwToolExit(
      'The project templates live in $kTemplatesDirectoryName/$kProjectTemplatesDirectoryName/ '
      'next to the tool, and there are none under '
      '${globals.templatePaths.root(globals.fs).path}.\n'
      'Install them again with $kInstallCommand, or set $kToolRootEnvironmentVariableName '
      'to a scribe_tools checkout.',
    );
  }

  /// Writes what the new project declares and does not yet carry.
  ///
  /// The scaffold lays down the files a project is written in; the forge lays
  /// down the ones it derives from what it declares, which is `configuration/`
  /// with a block per target and a file per package that asks to be configured.
  /// Running it here is what makes a project correct the moment it exists,
  /// rather than correct after a command nobody was told to run.
  ///
  /// It runs against the project that was just made and not the directory the
  /// command was typed in, which holds no project at all: everything the forge
  /// reaches for goes through the context, so putting the new project there is
  /// what lets it read a manifest that is one directory down.
  Future<void> _forge(Directory root) async {
    final Project made = Project.fromDirectory(root);

    await globals.context.run<void>(
      name: 'forge the new project',
      overrides: <Type, Generator>{Project: () => made},
      body: () {
        final ForgeReport report = Forge(project: made, packages: Packages.load().active).run(write: true);

        for (final ForgeEntry entry in report.entries) {
          if (entry.verdict == ForgeVerdict.written) globals.logger.printTrace('[create] forged ${entry.name}');
        }
      },
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
