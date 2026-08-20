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


import 'discovered_source.dart';
import 'emitter.dart';
import 'scanner.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/base/common.dart';


Future<void> generateRoutes() async {
  final DiscoveredSource source = await RouteScanner.discover();
  final String bin = kToolName;

  final String header = '// This file is auto-generated do not edit manually.\n'
      '// Run: $bin gen routes\n';

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.routes.writeAsString(RoutesEmitter(source).render(header));

  globals.logger.printStatus(
    '${source.routes.length} paths on ${source.nodes.length} nodes \u2192 ${globals.project.generatedDirectoryName}/sdk/js/routes.ts',
  );
}

class GenRoutesCommand extends ScribeCommand {
  GenRoutesCommand();

  @override
  String get name => 'routes';

  @override
  String get description => 'Walk lib/src/<node>/ and write the route table the worker reads at startup.';

  @override
  Future<ScribeCommandResult> runCommand() async {
    await generateRoutes();
    return const ScribeCommandResult.success();
  }
}
