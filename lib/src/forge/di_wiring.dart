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
import 'package:scribe_tools/src/forge/declaration_scan.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The marker that finds a class registering itself in the DI container.
const DeclaredKind _singletonMarker = DeclaredKind(bucket: 'di', package: 'alchemy', marker: 'Singleton');

/// The marker that finds a file registering something by hand, the way a `@module` would in
/// `injectable`: `container.registerSingleton(GroundSdk, () => GroundSdk.I)`, written next to
/// whatever else the file declares, with no class and no decorator to mark it.
const DeclaredKind _containerMarker = DeclaredKind(bucket: 'di', package: 'alchemy', marker: 'container');

/// Writes the imports that make every `@Singleton` class, and every file that reaches for the
/// container by hand, run.
///
/// A class marked `@Singleton` puts itself in the shared container the moment its module is
/// imported, and a file that calls `container.registerSingleton` by hand does the same thing by
/// running its own code: neither needs a second step. This file only has to be imported once,
/// before anything resolves a token, and the worker does that on its own. There is no
/// `configureDependencies()` to write and no place to call it, unlike `injectable`'s
/// `@InjectableInit()`: that call exists in Dart because nothing there registers itself at
/// import, and here everything already does.
///
/// Every `.ts` file of the project is scanned, `lib/` and beyond, with nothing to declare for
/// the search itself to reach anywhere: the tree is walked whole, the same way it already is for
/// `Singleton` when nothing named a `sources:` root. What `sources:` still decides is narrower,
/// and unrelated to being found: whether what was found can be **imported at all**. A path
/// outside `lib/` and outside every `sources:` root has no alias, `@app/` or otherwise, and
/// `problems` refuses it, saying which directory to add rather than writing an import that would
/// not resolve. See `scribe_manifest.dart` for `sources:` itself.
Future<void> generateDiWiring() async {
  final Map<DeclaredKind, List<String>> found = DeclarationScanner.scan(
    globals.project.directory,
    globals.project.directory.path,
    <DeclaredKind>[_singletonMarker, _containerMarker],
  );
  final List<String> files = <String>{...found[_singletonMarker]!, ...found[_containerMarker]!}.toList()..sort();

  final Set<String> sourceNames = globals.project.manifest.sources.toSet();
  final List<String> unreachable = <String>[
    for (final String file in files)
      if (!_reachable(file, sourceNames)) file,
  ];

  if (unreachable.isNotEmpty) {
    throwToolExit(
      'The following file(s) reach the DI container from outside lib/, with no sources: '
      'root that covers them, so no import could be written for them:\n'
      '${unreachable.map((String file) => '  $file').join('\n')}\n'
      'Add their top directory under sources: in config.yaml. For "${unreachable.first}", that is:\n'
      'sources:\n'
      '  - ${p.split(unreachable.first).first}',
    );
  }

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.di.writeAsString(
    '// This file is auto-generated do not edit manually.\n'
    '// Run: $kToolName forge\n'
    '\n'
    '${files.map((String file) => 'import "${_specifierOf(file)}";').join('\n')}'
    '${files.isEmpty ? '' : '\n'}',
  );

  globals.logger.printStatus(
    '${files.length} file(s) wired into the DI container, written to '
    '${globals.project.generatedDirectoryName}/sdk/js/di.ts',
  );
}

/// Whether [file], a path relative to the project root, has an alias to be imported through.
bool _reachable(String file, Set<String> sourceNames) {
  final String top = p.split(file).first;
  return top == 'lib' || sourceNames.contains(top);
}

/// [file], a path relative to the project root, as the alias that reaches it.
///
/// The first segment says which root it came from: `lib` reaches it as `@app/`,
/// the alias every route already imports through, and a `sources:` entry
/// reaches it as `@<name>/`, its own name, since `problems` already refused a
/// name `import_map.dart` could not turn into one.
String _specifierOf(String file) {
  final List<String> segments = p.split(file);
  final String alias = segments.first == 'lib' ? 'app' : segments.first;

  return '@$alias/${segments.skip(1).join('/')}';
}
