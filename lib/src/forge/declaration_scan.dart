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
import 'package:scribe_tools/src/package/declares.dart';
import 'package:scribe_tools/src/packages.dart';

/// One kind of declaration a project may write, as the package that offers it spells it.
///
/// Nothing about a kind is known here. A package says in its entry's `$kDeclaresExport` export
/// which buckets it opens and what marks a file as belonging to one, and this is that entry with
/// the package it came from kept alongside, so a collision between two packages can name them
/// both.
class DeclaredKind {
  /// Holds the kind [package] declared, loaded by [bucket] and marked by [marker].
  const DeclaredKind({required this.bucket, required this.package, required this.marker});

  /// The name of the generated function that loads every file of this kind.
  final String bucket;

  /// The name of the package whose manifest opened this bucket.
  final String package;

  /// The symbol a project file imports from [package]'s door to declare one.
  final String marker;

  /// The module alias a project reaches [package] by, `@scribe/<name>`.
  String get module => '@scribe/$package';

  /// Whether [specifier] is this package's door or a file under it.
  ///
  /// A project reaches the same names through the door itself and through a path
  /// under it, and the examples the packages ship use both, so both count.
  bool covers(String specifier) => specifier == module || specifier.startsWith('$module/');
}

/// The extension of a file this scan reads.
const String _sourceExtension = '.ts';

/// The directory a scan of `lib/` never walks into.
const String _vendorDirectory = 'node_modules';

const String _typeKeyword = 'type ';

/// A named import clause and the module it reads from.
///
/// Only the two the marker test needs are matched: which module, and which names.
/// A default import and a namespace import carry no name from the module, so
/// neither can tell a declaration apart and neither is parsed.
final RegExp _namedImport = RegExp('''import\\s+(type\\s+)?\\{([^}]*)\\}\\s*from\\s*['"]([^'"]+)['"]''');

/// The kinds the packages a project mounts let it declare, sorted by bucket.
///
/// A mounted package carrying no entry, or one exporting no `$kDeclaresExport`, opens no bucket.
/// What a package hands over is what its code says it hands over, and saying nothing is a package
/// that declares nothing.
///
/// [packages] is read again from disk when left out; a caller that already holds one, `forge`
/// does, passes it instead so the same closure is not resolved twice.
///
/// Throws a [ToolExit] when two mounted packages open the same bucket. One file would then be
/// imported for two meanings, and picking either one silently is the one answer that cannot be
/// right.
List<DeclaredKind> mountedKinds({Packages? packages}) {
  final Map<String, Map<String, String>> opened = <String, Map<String, String>>{
    for (final Package package in (packages ?? Packages.load()).active)
      package.name: readDeclares(package.directory.path, package.name),
  };

  return kindsOf(opened);
}

/// The kinds [opened] declares, from a package name to the buckets its entry opens.
///
/// Throws a [ToolExit] when two of them open the same bucket.
List<DeclaredKind> kindsOf(Map<String, Map<String, String>> opened) {
  final Map<String, DeclaredKind> byBucket = <String, DeclaredKind>{};

  for (final MapEntry<String, Map<String, String>> entry in opened.entries) {
    for (final MapEntry<String, String> declared in entry.value.entries) {
      final DeclaredKind? taken = byBucket[declared.key];
      if (taken != null) {
        throwToolExit(
          '[gen:code] "${entry.key}" and "${taken.package}" both open "${declared.key}" through their '
          'entry\'s "$kDeclaresExport". A project file would be loaded for two meanings at once, so one '
          'of the two has to name its bucket something else.',
        );
      }

      byBucket[declared.key] = DeclaredKind(bucket: declared.key, package: entry.key, marker: declared.value);
    }
  }

  return byBucket.values.toList()..sort((DeclaredKind a, DeclaredKind b) => a.bucket.compareTo(b.bucket));
}

/// Turns the file tree of `lib/` into the declarations it holds, bucket by bucket.
///
/// A developer puts a declaration where the code that uses it lives and names the
/// file after what it declares, so neither the path nor the name can be read.
/// What is read is the import: a file that constructs a `Queue` has to have
/// imported `Queue` from the package that publishes it.
///
/// The whole of `lib/` is walked, not just `lib/src/`, because a declaration is
/// not a route and nothing confines it to the served tree.
class DeclarationScanner {
  const DeclarationScanner._();

  /// Scans the current project's `lib/` for the [kinds] its packages opened.
  ///
  /// A project without a `lib/` answers an empty list per kind rather than
  /// failing: every command that needs one has refused the call before this runs.
  static Map<DeclaredKind, List<String>> discover(List<DeclaredKind> kinds) =>
      scan(globals.project.lib, globals.project.directory.path, kinds);

  /// Scans [lib] as a project's `lib/`, writing paths relative to [projectRoot].
  ///
  /// Every kind of [kinds] is a key of the result, so a mounted package whose
  /// bucket nothing fills answers an empty list rather than nothing at all. The
  /// lists are sorted, which is what keeps the generated file from following the
  /// order the file system happened to hand its entries back in.
  static Map<DeclaredKind, List<String>> scan(Directory lib, String projectRoot, List<DeclaredKind> kinds) {
    final Map<DeclaredKind, List<String>> found = <DeclaredKind, List<String>>{
      for (final DeclaredKind kind in kinds) kind: <String>[],
    };

    if (kinds.isEmpty || !lib.existsSync()) return found;

    for (final File file in _sourcesOf(lib)) {
      final Set<DeclaredKind> matched = kindsIn(file.readAsStringSync(), kinds);
      if (matched.isEmpty) continue;

      final String relative = p.relative(file.path, from: projectRoot);
      for (final DeclaredKind kind in matched) {
        found[kind]!.add(relative);
      }
    }

    for (final List<String> files in found.values) {
      files.sort();
    }

    return found;
  }

  /// The kinds of [kinds] that [source] declares, which is none for most files.
  ///
  /// A file that declares a queue and a cron lands in both buckets: the two are
  /// loaded at different moments and the file's effect is wanted at each.
  static Set<DeclaredKind> kindsIn(String source, List<DeclaredKind> kinds) {
    final Set<DeclaredKind> matched = <DeclaredKind>{};

    for (final RegExpMatch match in _namedImport.allMatches(source)) {
      if (match.group(1) != null) continue;

      final String specifier = match.group(3)!;
      final Set<String> names = _namesOf(match.group(2)!);

      for (final DeclaredKind kind in kinds) {
        if (kind.covers(specifier) && names.contains(kind.marker)) matched.add(kind);
      }
    }

    return matched;
  }

  /// The names an import clause binds, its type-only members left out.
  ///
  /// A name is taken as it stands in the module, before any `as`, because that is
  /// the one the marker is written as. A `type` member is dropped: it is erased at
  /// compile time, so a file that imports only those constructs nothing and
  /// declares nothing.
  static Set<String> _namesOf(String clause) => <String>{
    for (final String member in clause.split(','))
      if (_imported(member.trim()) case final String name when name.isNotEmpty) name,
  };

  static String _imported(String member) {
    if (member.startsWith(_typeKeyword)) return '';

    final int alias = member.indexOf(' as ');
    return (alias == -1 ? member : member.substring(0, alias)).trim();
  }

  /// Every `.ts` file under [directory], the trees a scan never enters left out.
  ///
  /// Hidden directories are skipped, which is what keeps the generated tree out:
  /// it is written to `.<name>/`, and so is anything else a tool leaves behind.
  static List<File> _sourcesOf(Directory directory) {
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
}
