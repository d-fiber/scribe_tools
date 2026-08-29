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

/// The extension of a file this scan reads.
const String _sourceExtension = '.ts';

/// The directory a scan never walks into.
const String _vendorDirectory = 'node_modules';

/// A specifier named the ordinary way, `import`, `export`, or a re-export, all sharing `from`.
///
/// Anchored at the start of a line and cut off at the first `;`, so that the word "from" inside a
/// test's own name, "whatever column it came from", is never read as the tail of a statement that
/// is actually two lines above it. A multi-line named import is still one match: the brace block
/// between `import` and `from` may cross lines, and nothing here needs what is inside it, only the
/// specifier after `from`.
final RegExp _fromClause = RegExp(r'''^[ \t]*(?:import|export)\b[^;]*?\bfrom\s*["']([^"']+)["']''', multiLine: true);

/// A side-effect import, `import "specifier";`, carrying no name at all.
final RegExp _sideEffectImport = RegExp(r'''^[ \t]*import\s*["']([^"']+)["']''', multiLine: true);

/// A dynamic import, wherever an expression may call it.
final RegExp _dynamicImport = RegExp(r'''import\s*\(\s*["']([^"']+)["']''');

/// Every specifier under [directory] that a `.ts` file imports or re-exports.
///
/// A relative specifier is left out, since it names a file of the same package rather than
/// something outside it. So is one that starts with `@scribe/`: that is either another package,
/// held to what `dependencies:` declares, or a surface of the framework itself, granted without
/// being asked for. What is left is what the checkout has to pin for the file to resolve, and
/// nothing about it is read from a manifest, because nothing declares it any more.
Set<String> externalSpecifiersIn(String directory) {
  final Set<String> found = <String>{};
  final Directory held = globals.fs.directory(directory);
  if (!held.existsSync()) return found;

  for (final File file in _sourcesOf(held)) {
    final String source = file.readAsStringSync();
    for (final RegExp pattern in <RegExp>[_fromClause, _sideEffectImport, _dynamicImport]) {
      for (final RegExpMatch match in pattern.allMatches(source)) {
        final String specifier = match.group(1)!;
        if (specifier.startsWith('.') || specifier.startsWith('@scribe/')) continue;
        found.add(specifier);
      }
    }
  }

  return found;
}

/// Every `.ts` file under [directory], the trees a scan never enters left out.
List<File> _sourcesOf(Directory directory) {
  final List<FileSystemEntity> entries = directory.listSync(followLinks: false)
    ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));

  final List<File> sources = <File>[];
  for (final FileSystemEntity entry in entries) {
    final String basename = p.basename(entry.path);

    if (entry is Directory) {
      if (basename.startsWith('.') || basename == _vendorDirectory) continue;
      sources.addAll(_sourcesOf(entry));
      continue;
    }

    if (entry is File && basename.endsWith(_sourceExtension) && !basename.startsWith('.')) sources.add(entry);
  }

  return sources;
}
