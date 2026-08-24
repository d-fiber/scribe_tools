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
import 'package:scribe_tools/src/globals.dart' as globals;

/// The file whose presence makes a directory a package, and the only thing that says so.
const String kManifestFile = 'package.yaml';

/// The directory holding everything a package is made of.
const String kLibraryDirectory = 'lib';

/// The directory, inside [kLibraryDirectory], holding the code itself.
const String kSourceDirectory = 'src';

/// The directory holding the tests, which a package cannot be without.
const String kTestsDirectory = 'tests';

/// The directory, inside [kTestsDirectory], holding the tests that need the stack up.
const String kE2eDirectory = 'e2e';

/// The directory, inside [kTestsDirectory], holding what a consumer imports to stub this package.
const String kTestingDirectory = 'testing';

/// The file keeping what the tools generate out of the repository.
const String kIgnoreFile = '.gitignore';

/// The suffix a test file carries.
const String kTestSuffix = '.test.ts';

/// The entry of the package called [name], relative to the package.
///
/// It is derived and never declared. A package has one way in, it is named after
/// the package, and the layout says where it sits, so a manifest that could point
/// somewhere else would only be a chance for the two to disagree.
String entryOf(String name) => '$kLibraryDirectory/$name.ts';

/// What [directory] is missing to be a package called [name], empty when nothing.
List<String> layoutProblems(String directory, String name) {
  final List<String> missing = <String>[];

  if (!globals.fs.file(p.join(directory, kIgnoreFile)).existsSync()) {
    missing.add('it has no $kIgnoreFile, so what the tools generate would be committed with the source.');
  }

  if (!globals.fs.directory(p.join(directory, kLibraryDirectory)).existsSync()) {
    missing.add('it has no $kLibraryDirectory/, which is where a package holds what it is made of.');
  } else {
    if (!globals.fs.file(p.join(directory, entryOf(name))).existsSync()) {
      missing.add('it has no ${entryOf(name)}, which is the one file everything else reaches it through.');
    }
    if (!globals.fs.directory(p.join(directory, kLibraryDirectory, kSourceDirectory)).existsSync()) {
      missing.add('it has no $kLibraryDirectory/$kSourceDirectory/, which is where the code goes.');
    }
  }

  missing.addAll(_testProblems(directory));
  return missing;
}

List<String> _testProblems(String directory) {
  final Directory tests = globals.fs.directory(p.join(directory, kTestsDirectory));
  if (!tests.existsSync()) {
    return <String>['it has no $kTestsDirectory/, and a package nobody tested is not one.'];
  }

  final List<String> missing = <String>[];
  if (!globals.fs.directory(p.join(tests.path, kE2eDirectory)).existsSync()) {
    missing.add('it has no $kTestsDirectory/$kE2eDirectory/, which is where the tests that need the stack up go.');
  }
  if (!_holdsATest(tests)) {
    missing.add(
      'its $kTestsDirectory/ holds no $kTestSuffix file, so the directory says it was tested and nothing did.',
    );
  }

  return missing;
}

bool _holdsATest(Directory tests) {
  for (final FileSystemEntity entry in tests.listSync(followLinks: false)) {
    if (entry is File && entry.path.endsWith(kTestSuffix)) return true;
    if (entry is Directory && p.basename(entry.path) != kE2eDirectory && _holdsATest(entry)) {
      return true;
    }
  }
  return false;
}
