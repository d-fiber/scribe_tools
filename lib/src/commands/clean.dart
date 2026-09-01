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
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Removes what `forge` and `gen` derived, so the next run writes it fresh.
///
/// Which of the two it does is read from the directory it runs in, the same
/// way `forge` decides: a `config.yaml` makes it a project, a `package.yaml`
/// makes it a package.
///
/// It only ever removes what is gitignored and rebuilt from a manifest a
/// human still owns: the derived tree of a project, and the resolution of a
/// package. A project's `.scribe/state/` is not one of them. It holds what
/// `deploy` provisioned, not what `forge` derived, and only `destroy` is
/// allowed to take it down.
class CleanCommand extends ScribeCommand {
  /// Declares the flag that lists without removing.
  CleanCommand() {
    argParser.addFlag('dry-run', abbr: 'n', negatable: false, help: 'List what would be removed, and remove nothing.');
  }

  @override
  String get name => 'clean';

  @override
  String get description => 'Remove what forge and gen derived, so the next run writes it fresh.';

  @override
  String get invocation => 'scribe clean [--dry-run]';

  /// It decides for itself whether it is in a project or a package.
  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final Directory here = globals.fs.currentDirectory;

    if (Project.isProjectRoot(here)) return _clean(<Directory>[project.generated.directory]);
    if (here.childFile(kManifestFile).existsSync()) {
      return _clean(<Directory>[
        here.childDirectory(kResolutionDirectory),
        here.childDirectory('tests').childDirectory('e2e').childDirectory('.generated'),
        here.childDirectory('tests').childDirectory('e2e').childDirectory('.postgres'),
      ]);
    }

    throwToolExit(
      'clean runs at the root of a scribe project or of a package, and ${here.path} is neither: '
      'it holds no ${Project.configFileName} and no $kManifestFile.',
    );
  }

  Future<ScribeCommandResult> _clean(List<Directory> candidates) async {
    final bool dryRun = boolArg('dry-run');
    final List<Directory> present = candidates.where((Directory directory) => directory.existsSync()).toList();

    if (present.isEmpty) {
      globals.logger.printStatus('Nothing to clean, there is no derived state on disk.');
      return const ScribeCommandResult.success();
    }

    for (final Directory directory in present) {
      globals.logger.printStatus('${dryRun ? 'would remove' : 'removed'}  ${directory.path}');
      if (!dryRun) directory.deleteSync(recursive: true);
    }

    return const ScribeCommandResult.success();
  }
}
