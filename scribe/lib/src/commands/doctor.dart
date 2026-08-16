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
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/scribe_manifest.dart';
import 'package:scribe/src/secrets.dart';
import 'package:scribe/src/tools.dart';

class DoctorCommand extends ScribeCommand {
  DoctorCommand();

  static const List<ExternalTool> _everyTool = <ExternalTool>[
    ToolCatalog.git,
    ToolCatalog.deno,
    ToolCatalog.npm,
    ToolCatalog.docker,
  ];

  @override
  String get name => 'doctor';

  @override
  String get description => 'Report what this machine and this project are missing.';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    _reportMachine();
    final bool toolsReady = _reportTools();
    final bool projectReady = _reportProject();

    globals.logger.printStatus('');

    if (toolsReady && projectReady) {
      globals.logger.printStatus('${globals.terminal.successMark} Nothing to fix.', emphasis: true);
      return const ScribeCommandResult.success();
    }

    return const ScribeCommandResult.warning();
  }

  void _reportMachine() {
    globals.logger.printStatus('Machine', emphasis: true);
    globals.logger.printStatus('  ${globals.os.hostPlatform}');
    globals.logger.printStatus('  ${globals.shell.name}');

    final PackageManager? manager = PackageManager.detect();
    globals.logger.printStatus('  ${manager == null ? 'no package manager found' : '${manager.name} available'}');
    globals.logger.printStatus('');
  }

  bool _reportTools() {
    globals.logger.printStatus('Tools', emphasis: true);

    final PackageManager? manager = PackageManager.detect();
    bool ready = true;

    for (final ExternalTool tool in _everyTool) {
      final File? found = globals.os.which(tool.executable);

      if (found != null) {
        globals.logger.printStatus('  ${globals.terminal.successMark} ${tool.name.padRight(8)} ${found.path}');
        continue;
      }

      ready = false;
      globals.logger.printStatus(
        '  ${globals.terminal.warningMark} ${tool.name.padRight(8)} missing — ${tool.purpose}',
        color: TerminalColor.yellow,
      );
      globals.logger.printStatus(
        '    ${manager == null ? tool.homepage : manager.commandFor(tool).join(' ')}',
      );
    }

    globals.logger.printStatus('');
    return ready;
  }

  bool _reportProject() {
    globals.logger.printStatus('Project', emphasis: true);

    final Project? here = Project.currentOrNull;
    if (here == null) {
      globals.logger.printStatus('  no ${Project.configFileName} here — this is not a project root');
      return true;
    }

    bool ready = true;

    for (final String entry in here.missingEntries) {
      ready = false;
      globals.logger.printStatus('  ${globals.terminal.warningMark} $entry is missing', color: TerminalColor.yellow);
    }

    for (final ManifestProblem problem in here.manifest.problems) {
      ready = false;
      globals.logger.printStatus('  ${globals.terminal.warningMark} $problem', color: TerminalColor.yellow);
    }

    if (SecretsStore.forProject(here).identityLines.isEmpty && SecretsStore.forProject(here).exists) {
      ready = false;
      globals.logger.printStatus(
        '  ${globals.terminal.warningMark} ${SecretsStore.fileName} is here, but no key opens it',
        color: TerminalColor.yellow,
      );
    }

    if (ready) globals.logger.printStatus('  ${globals.terminal.successMark} ${here.name}');

    return ready;
  }
}
