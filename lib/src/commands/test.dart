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

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/tools.dart';

/// Resolves a framework package and runs its tests.
///
/// It works on a checkout of the framework, never on a project, which is why it
/// asks for no project root. It resolves the package the way `scribe forge`
/// does, every time: resolving is cheap, and a stale map would answer a test
/// run against yesterday's dependencies.
class TestCommand extends ScribeCommand {
  /// Takes the arguments the runtime is handed after the ones this reads.
  TestCommand() {
    argParser.addOption('filter', valueHelp: 'text', help: 'Only the cases whose name holds this.');
  }

  @override
  String get name => 'test';

  @override
  String get description => "Run a framework package's tests.";

  @override
  String get invocation => 'scribe test [directory] [--filter <text>]';

  @override
  bool get requiresProject => false;

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.deno];

  /// What a package's tests are allowed to reach, and nothing beyond it.
  ///
  /// The four are what the framework grants its own suite. Reading the environment
  /// is what an npm dependency does the moment it loads, reading the system is
  /// what a runtime probe does, and reading files is what the runtime does to
  /// reach the package at all. Writing is what a driver that puts a file on disk
  /// does, and withholding it meant the tool could not test the packages that
  /// have one: eighteen of foundation's tests failed on a temporary directory,
  /// with no service involved.
  ///
  /// Nothing here reaches the network: a test that needs the stack up is an
  /// end-to-end test, and those are run against a stack rather than from here.
  static const List<String> kTestPermissions = <String>['--allow-env', '--allow-sys', '--allow-read', '--allow-write'];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String directory = p.absolute(optionalPositional('directory') ?? globals.fs.currentDirectory.path);
    final Sdk sdk = findSdk(from: directory);

    final Resolution resolution = resolve(directory, sdk);

    if (!globals.fs.directory(p.join(directory, kTestsDirectory)).existsSync()) {
      throwToolExit('$directory has no $kTestsDirectory/, so there is nothing to run.');
    }

    final String? filter = stringArg('filter');
    final int status = await globals.processRunner.run(<String>[
      'deno',
      'test',
      '--import-map',
      resolution.importMap,
      ...kTestPermissions,
      if (filter != null) ...<String>['--filter', filter],
      kTestsDirectory,
    ], workingDirectory: directory);

    return status == 0 ? const ScribeCommandResult.success() : const ScribeCommandResult.fail();
  }
}
