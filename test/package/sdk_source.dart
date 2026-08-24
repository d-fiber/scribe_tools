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

/// Writes a checkout at [root] publishing [version], enough for a package to resolve against.
///
/// It carries the three directories a checkout is recognised by, the `VERSION`
/// file the version is read from, the language's own manifest, and the import map
/// everything outside the framework is pinned in. [languageExports] is what the
/// language publishes, from the specifier a package writes to the file inside
/// `host/alchemy/` that answers it.
void writeCheckout(
  Directory root, {
  String version = '3.0.1',
  Map<String, String> languageExports = const <String, String>{'.': './mod.ts'},
  String imports = '{"imports":{"@scribe/core/":"./core/"}}',
}) {
  for (final String directory in <String>['sdk', 'host', 'protocol']) {
    Directory(p.join(root.path, directory)).createSync(recursive: true);
  }

  File(p.join(root.path, kSdkVersionFile)).writeAsStringSync('$version\n');
  File(p.join(root.path, p.joinAll(p.posix.split(kSdkImportMapFile))))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('$imports\n');

  final String alchemy = p.join(root.path, 'host', 'alchemy');
  for (final String file in languageExports.values) {
    File(p.join(alchemy, p.joinAll(p.posix.split(file))))
      ..createSync(recursive: true)
      ..writeAsStringSync('export {};\n');
  }

  final String exports = languageExports.entries
      .map((MapEntry<String, String> entry) => '"${entry.key}":"${entry.value}"')
      .join(',');
  File(p.join(alchemy, 'deno.json')).writeAsStringSync('{"exports":{$exports}}\n');
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
