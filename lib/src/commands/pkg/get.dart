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
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Works out what a package's specifiers answer to, and writes it down.
class PkgGetCommand extends ScribeCommand {
  @override
  String get name => 'get';

  @override
  String get description => 'Work out what this package reaches, and write it down for the tools.';

  @override
  String get invocation => 'scribe pkg get [directory]';

  @override
  bool get requiresProject => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String directory = p.absolute(optionalPositional('directory') ?? globals.fs.currentDirectory.path);
    final Sdk sdk = findSdk(from: directory);
    final Resolution resolution = resolve(directory, sdk);

    globals.logger.printStatus('Resolved against scribe ${sdk.version} in ${sdk.root}');
    for (final MapEntry<String, String> held in resolution.imports.entries) {
      globals.logger.printStatus('  ${held.key} ${held.value}');
    }
    globals.logger.printStatus('');
    globals.logger.printStatus('Written to ${resolution.file}, which git ignores and nobody edits.');
    globals.logger.printStatus(
      'What the runtime is handed was built outside the package, in ${resolution.runtimeConfig}.',
    );

    return const ScribeCommandResult.success();
  }
}
