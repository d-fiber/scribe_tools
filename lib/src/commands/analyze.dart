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
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/checks.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Reads every package of the framework under the roots and says what is wrong with them.
///
/// It works on a checkout of the framework, never on a project, which is why it
/// asks for no project root. What it reads is what is on disk: it opens no
/// checkout and resolves nothing.
class AnalyzeCommand extends ScribeCommand {
  /// Declares `--watch`, which reruns this analysis on a change under the roots.
  AnalyzeCommand() {
    argParser.addFlag(
      ScribeCommand.watchOption,
      negatable: false,
      help: 'Run again every time a file under a root changes, instead of once.',
    );
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Read the framework packages under a directory and report what is wrong with them.';

  @override
  String get invocation => 'scribe analyze <directory>... [--watch]';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final List<String> roots = <String>[
      for (final String given in argResults?.rest ?? const <String>[]) p.absolute(given),
    ];

    if (roots.isEmpty) roots.add(globals.fs.currentDirectory.path);

    final ScribeCommandResult first = await _analyze(roots);
    if (!boolArg(ScribeCommand.watchOption)) return first;

    return watchAndRerun(<Directory>[
      for (final String root in roots) globals.fs.directory(root),
    ], () => _analyze(roots));
  }

  Future<ScribeCommandResult> _analyze(List<String> roots) async {
    final List<DiscoveredPackage> packages = discover(roots);
    if (packages.isEmpty) throwToolExit('No package under ${roots.join(', ')}.');

    final List<Problem> problems = check(packages);
    for (final Problem problem in problems) {
      globals.logger.printError('$problem');
    }

    if (problems.isEmpty) {
      globals.logger.printStatus('${_counted(packages.length, 'package')}, nothing to report.');
      return const ScribeCommandResult.success();
    }

    globals.logger.printError('');
    globals.logger.printError(
      '${_counted(problems.length, 'problem')} across ${_counted(packages.length, 'package')}.',
    );
    return const ScribeCommandResult.fail();
  }

  String _counted(int many, String what) => many == 1 ? '1 $what' : '$many ${what}s';
}
