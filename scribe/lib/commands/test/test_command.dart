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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:path/path.dart' as p;

import '../../core/console/console.dart';
import '../../core/file_system_entity/paths.dart';
import '../../core/file_system_entity/source.dart';
import '../../core/project/gate.dart';

class TestCommand extends Command {
  const TestCommand();

  @override
  String get name => 'test';

  @override
  String get description => 'Run the project test suite (lib/tests/ only).';

  @override
  List<Middleware> get middlewares => const <Middleware>[requireInitializedProject];

  @override
  Future<void> run(Context cli) async {
    final String functionsDir = Paths.kernel.scribe.host.path;
    final String projectTests = Paths.project.tests.path;
    final String envFile = p.join(functionsDir, 'tests', '.env.test');

    // Les tests project importent `@app/` et l'alias du projet, deux alias que la
    // config du SDK ne connaît plus depuis que celui-ci tient seul : c'est
    // la carte d'imports générée du projet qui les porte.
    final Source projectConfig = Paths.alchemy.sdk.js.scribeJson;
    if (!projectConfig.existsSync()) {
      throw CliException('${projectConfig.path} is missing run `gen code` first.');
    }

    cli.log.info('Running $projectTests...');
    print('');

    await Deno.test()
        .allowEnv()
        .allowSys()
        .allowNet()
        .allowRead()
        .noCheck()
        .config(projectConfig.path)
        .envFile(envFile)
        .scriptArg(projectTests)
        .execute(cwd: functionsDir);

    print('');
    cli.log.info('All tests passed.');
  }
}
