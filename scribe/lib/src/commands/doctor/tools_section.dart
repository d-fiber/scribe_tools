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
import 'package:scribe/src/tools.dart';

/// The tools a project needs at one point or another.
const List<ExternalTool> everyTool = <ExternalTool>[
  ToolCatalog.git,
  ToolCatalog.deno,
  ToolCatalog.npm,
  ToolCatalog.docker,
];

/// Reports where each of [everyTool] is, and returns whether they are all there.
///
/// Nothing is installed. The exact command is shown and left for the user to
/// run — a diagnosis that installed packages while reporting would be a
/// surprise, and it is the difference between this and a command that declares
/// what it needs.
bool reportTools(PackageManager? manager) {
  globals.logger.printStatus('Tools', emphasis: true);
  bool ready = true;

  for (final ExternalTool tool in everyTool) {
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
    globals.logger.printStatus('    ${manager == null ? tool.homepage : manager.commandFor(tool).join(' ')}');
  }

  globals.logger.printStatus('');
  return ready;
}
