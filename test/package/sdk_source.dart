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

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/package/sdk.dart';

/// What a checkout publishes when a test does not care what it publishes.
///
/// It carries the language and the one directory of the framework a package
/// reaches by path, which is the least a package can be resolved against.
const Map<String, String> kCheckoutImports = <String, String>{
  '@scribe/alchemy': './engine/alchemy/mod.ts',
  '@scribe/contracts/': './engine/contracts/',
};

/// Writes a checkout at [root] publishing [version], enough for a package to resolve against.
///
/// It carries the three directories a checkout is recognised by, the tracked
/// `scribe.workspace.json` the version and the import map [imports] are written into, and no
/// `deno.json`, the same as a bare clone. That map is the whole of what a checkout says it
/// carries: the language, the framework's own directories, and every version outside the
/// framework.
///
/// Every entry answering a path inside the checkout gets a file written for it,
/// so that a test reading back what a package reaches finds something behind it.
void writeCheckout(Directory root, {String version = '3.0.1', Map<String, String> imports = kCheckoutImports}) {
  for (final String directory in <String>['sdk', 'engine', 'protocol']) {
    Directory(p.join(root.path, directory)).createSync(recursive: true);
  }

  for (final String answer in imports.values) {
    if (!answer.startsWith('./') || !answer.endsWith('.ts')) continue;

    File(p.join(root.path, p.joinAll(p.posix.split(answer))))
      ..createSync(recursive: true)
      ..writeAsStringSync('export {};\n');
  }

  // A directory under `engine/` is a layer once it carries its own `_collection.json`, and a
  // package's resolution grants every layer without being asked. `@scribe/contracts/` is the one
  // this checkout answers for, so it carries the file `layerImports` reads, naming the same entry
  // the root map already carries.
  if (imports.containsKey('@scribe/contracts/')) {
    File(p.join(root.path, 'engine', 'contracts', kLayerCollectionFile))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"@scribe/contracts/":"./"}\n');
  }

  final String written = imports.entries
      .map((MapEntry<String, String> entry) => '"${entry.key}":"${entry.value}"')
      .join(',');
  File(p.join(root.path, kSdkWorkspaceFile))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('{"version":"$version","imports":{$written}}\n');
}

/// Runs [body] with [home] as the home directory the tool writes under.
///
/// Where a resolution puts what it builds for the runtime is derived from the
/// home directory, so a suite that let the real one through would write into the
/// directory of whoever ran it and read back whatever was already there.
Future<T> withHome<T>(Directory home, FutureOr<T> Function() body) => AppContext.current.run<T>(
  name: 'test',
  body: body,
  overrides: <Type, Generator>{
    Platform: () => FakePlatform(environment: <String, String>{'HOME': home.path}),
  },
);
