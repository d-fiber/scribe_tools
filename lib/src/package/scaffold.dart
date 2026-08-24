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
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/name.dart';
import 'package:scribe_tools/src/package/sdk.dart';

/// What writing a package left on disk.
class CreatedPackage {
  /// Records that a package was written into [directory], leaving [files] behind.
  const CreatedPackage({required this.directory, required this.files});

  /// The path of the directory the package was written into.
  final String directory;

  /// The files written, relative to the package, in the order they were written.
  final List<String> files;
}

/// Writes the package called [name] inside [at], written against [sdk], and
/// answers what it left.
///
/// What it writes is the mandatory layout and nothing else: the manifest, the
/// ignore file, the one way in, the directory the code goes in, and a test
/// directory that already holds a test. A skeleton that stopped short of any of
/// those would produce a package the checks refuse, which is the one thing a
/// scaffold must not do.
///
/// The checkout is needed for the manifest alone, which has to name the framework
/// versions the package accepts. A skeleton that left that out would be a package
/// the very next command refuses.
///
/// Throws a [ToolExit] when [name] cannot name a package, or when something is
/// already at that path.
CreatedPackage createPackage(String at, String name, Sdk sdk) {
  final String? problem = packageNameProblem(name);
  if (problem != null) throwToolExit(problem);

  final String directory = p.join(at, name);
  if (globals.fs.directory(directory).existsSync() || globals.fs.file(directory).existsSync()) {
    throwToolExit('$directory already exists. Pick another name, or remove it first.');
  }

  final Map<String, String> files = <String, String>{
    kManifestFile: Manifest.skeleton(name, sdk.version),
    kIgnoreFile: _ignored(),
    entryOf(name): _entry(name),
    '$kLibraryDirectory/$kSourceDirectory/.gitkeep': '',
    '$kTestsDirectory/$name$kTestSuffix': _firstTest(name),
    '$kTestsDirectory/$kE2eDirectory/.gitkeep': '',
  };

  final List<String> written = <String>[];
  files.forEach((String path, String text) {
    final File target = globals.fs.file(p.join(directory, path));
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(text);
    written.add(path);
  });

  return CreatedPackage(directory: directory, files: written);
}

String _ignored() => <String>[
  '.DS_Store',
  '.env',
  '',
  'node_modules/',
  '',
  '.scribe/',
  '.vscode/',
  '$kTestsDirectory/$kE2eDirectory/.generated/',
  '$kTestsDirectory/$kE2eDirectory/.postgres/',
  '',
].join('\n');

String _entry(String name) =>
    '/**\n'
    ' * What "$name" hands whoever mounts it.\n'
    ' *\n'
    ' * Everything it is made of lives in `$kSourceDirectory/`, and this file is the only way in. A\n'
    ' * package may also export `wires`, `starts` and `stops` from here, which are the three moments\n'
    ' * the host runs it at.\n'
    ' */\n'
    '\n'
    'export {};\n';

String _firstTest(String name) =>
    'import { assertExists } from "@std/assert";\n'
    'import * as $name from "../${entryOf(name)}";\n'
    '\n'
    'Deno.test("$name can be reached through its entry", () => {\n'
    '  assertExists($name, "the entry did not load");\n'
    '});\n';
