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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/packages.dart';

/// Writes the imports that wire every mounted package into the host's ports.
///
/// A package carries a [registrationFile] only when it has something to hand
/// over, so the list is usually shorter than the mounted one. A package without
/// it contributes containers, SQL or a client and nothing the host has to be
/// told about.
///
/// The specifier is the package's own alias, `@scribe/<name>/`, which is the one
/// the import map this same command writes resolves to `packages/<name>/`. It is
/// therefore the name and never a path, and moving the checkout moves both ends
/// at once.
Future<void> generateRegistrations() async {
  final Packages packages = Packages.load();

  final List<String> specifiers = <String>[
    for (final Package package in packages.active)
      if (package.directory.childFile(registrationFile).existsSync()) '@scribe/${package.name}/$registrationFile',
  ]..sort();

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.registrations.writeAsString(
    '// This file is auto-generated do not edit manually.\n'
    '// Run: $kToolName gen code\n'
    '\n'
    '${specifiers.map((String specifier) => 'import "$specifier";').join('\n')}'
    '${specifiers.isEmpty ? '' : '\n'}',
  );

  globals.logger.printStatus(
    '${specifiers.length} package registration(s), written to '
    '${globals.project.generatedDirectoryName}/sdk/js/registrations.ts',
  );
}
