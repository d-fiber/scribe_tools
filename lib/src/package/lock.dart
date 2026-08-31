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
import 'package:scribe_tools/src/base/common.dart';
import 'package:yaml/yaml.dart';

/// Where a locked package was found: the checkout's own `packages/`, a sibling
/// directory in the same workspace, or a `path:` a project wrote.
///
/// A locked entry never carries the path itself, only this and a version: the
/// path is true on one machine and false on the next, and re-deriving it is
/// exactly what resolving does. Locking a path would freeze a fact resolving
/// already answers, and it would answer it wrong on every other checkout.
enum LockSource {
  /// Found under the checkout's own `packages/`.
  sdk,

  /// Found beside the thing being resolved, in the same workspace.
  workspace,

  /// Found at a `path:` a project's `config.yaml` wrote.
  path;

  static LockSource _parse(String written, String where) => LockSource.values.firstWhere(
    (LockSource source) => source.name == written,
    orElse: () => throwToolExit('$where names a source of "$written", which is none of ${LockSource.values}.'),
  );
}

/// One dependency a lock has frozen: the version resolving found for it, and
/// where resolving found it.
class LockedPackage {
  /// Records that [name] was resolved to [version], found at [source].
  const LockedPackage({required this.name, required this.version, required this.source});

  /// The package's name.
  final String name;

  /// The version resolving found for it.
  final String version;

  /// Where resolving found it.
  final LockSource source;
}

/// What resolving decided, frozen so the next resolution can be compared against it.
///
/// A lock is committed, unlike `.scribe/resolution.json`: it names no path, only
/// versions, so what it says stays true on a machine that never ran the
/// resolution that wrote it. Resolving overwrites it every time, the way `pub
/// get` overwrites `pubspec.lock`; nobody edits it by hand, and nothing here
/// checks that nobody did.
class PackageLock {
  /// Records that resolving against framework [scribe] locked [packages].
  const PackageLock({required this.scribe, required this.packages});

  /// The framework version this lock was resolved against.
  final String scribe;

  /// Every dependency resolving locked, sorted by name.
  final List<LockedPackage> packages;

  /// The keys a lock document may carry, and no others.
  static const List<String> kLockKeys = <String>['scribe', 'packages'];

  /// The keys one locked package may carry, and no others.
  static const List<String> kEntryKeys = <String>['version', 'source'];

  /// The lock [source] spells, where [source] is the text of a lock file.
  ///
  /// [where] names the file in whatever this throws. Throws a [ToolExit] when
  /// the document does not hold together.
  static PackageLock parse(String source, String where) {
    final Object? document = _read(source, where);
    if (document is! Map) {
      throwToolExit('$where is not a mapping. It opens with "scribe:" and "packages:".');
    }

    for (final Object? key in document.keys) {
      if (kLockKeys.contains(key)) continue;
      throwToolExit('$where carries "$key", which a lock never writes.');
    }

    final Object? scribe = document['scribe'];
    if (scribe is! String || scribe.isEmpty) {
      throwToolExit('$where has no "scribe:", the framework version it was resolved against.');
    }

    final Object? packages = document['packages'];
    if (packages != null && packages is! Map) {
      throwToolExit('$where holds "packages:" as something other than a block of names.');
    }

    final List<LockedPackage> entries = <LockedPackage>[];
    (packages as Map<Object?, Object?>?)?.forEach((Object? name, Object? held) {
      if (held is! Map) throwToolExit('$where, at "$name": holds something other than version and source.');

      for (final Object? key in held.keys) {
        if (kEntryKeys.contains(key)) continue;
        throwToolExit('$where, at "$name": carries "$key", which a locked package never writes.');
      }

      final Object? version = held['version'];
      final Object? source = held['source'];
      if (version is! String || version.isEmpty) {
        throwToolExit('$where, at "$name": has no "version:".');
      }
      if (source is! String || source.isEmpty) {
        throwToolExit('$where, at "$name": has no "source:".');
      }

      entries.add(
        LockedPackage(name: '$name', version: version, source: LockSource._parse(source, '$where, at "$name"')),
      );
    });

    entries.sort((LockedPackage a, LockedPackage b) => a.name.compareTo(b.name));
    return PackageLock(scribe: scribe, packages: entries);
  }

  /// The lock in [file], or null when there is none.
  ///
  /// Throws a [ToolExit] when the file exists but cannot be read.
  static PackageLock? readFrom(File file) {
    if (!file.existsSync()) return null;
    return parse(file.readAsStringSync(), file.path);
  }

  /// The package called [name], or null when this lock does not carry one.
  LockedPackage? byName(String name) {
    for (final LockedPackage held in packages) {
      if (held.name == name) return held;
    }
    return null;
  }

  /// This lock, rendered as the text it is written to disk as.
  String render() {
    final StringBuffer buffer = StringBuffer('scribe: $scribe\n\npackages:\n');
    if (packages.isEmpty) buffer.write('\n');

    for (final LockedPackage held in packages) {
      buffer
        ..writeln('  ${held.name}:')
        ..writeln('    version: ${held.version}')
        ..writeln('    source: ${held.source.name}');
    }

    return buffer.toString();
  }

  /// Writes this lock to [file], creating its parent directory when needed.
  void writeTo(File file) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(render());
  }
}

Object? _read(String source, String where) {
  try {
    return _plain(loadYaml(source));
  } on YamlException catch (error) {
    throwToolExit('$where is not readable as YAML: ${error.message}');
  }
}

Object? _plain(Object? node) {
  if (node is YamlMap) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in node.entries) entry.key.toString(): _plain(entry.value),
    };
  }
  if (node is YamlList) return node.map(_plain).toList();
  return node;
}
