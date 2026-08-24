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

import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/scaffold.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Writes the mandatory layout of a new package, ready to pass the checks.
class PkgCreateCommand extends ScribeCommand {
  /// Takes the directory to write into, since it is not always the current one.
  PkgCreateCommand() {
    argParser.addOption(
      'in',
      valueHelp: 'directory',
      help: 'Where the package is written. The current directory when left out.',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description => 'Write a new package, laid out the way every package has to be.';

  @override
  String get invocation => 'scribe pkg create <name> [--in <directory>]';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String named = requirePositional(
      'name',
      explain:
          'The name becomes the directory, the segment of every import specifier that reaches the '
          'package, and the key a project writes to mount it. Lowercase letters and single '
          'underscores, as in "dynamic_links".',
    );

    final String inside = stringArg('in') ?? globals.fs.currentDirectory.path;
    final Sdk sdk = findSdk(from: inside);
    final CreatedPackage created = createPackage(inside, named, sdk);

    globals.logger.printStatus('Wrote ${created.directory}');
    for (final String file in created.files) {
      globals.logger.printStatus('  $file');
    }

    return const ScribeCommandResult.success();
  }
}
