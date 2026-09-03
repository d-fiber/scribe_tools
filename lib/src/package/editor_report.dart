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

import 'package:scribe_tools/src/package/import_fold.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/workspace.dart';
import 'package:scribe_tools/src/runtime/editor_projection.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';

/// One directory `scribe editor` was asked about: the runtime its manifest names, and whether a
/// resolution could be read for it.
class EditorPackage {
  /// Records what was found for the package at [directory].
  const EditorPackage({required this.directory, required this.runtime, required this.resolved});

  /// The directory this package was requested at.
  final String directory;

  /// The runtime this package's manifest names.
  final String runtime;

  /// Whether `.scribe/resolution.json` could be read for this package.
  ///
  /// False means `scribe forge` has to run here again before an editor can trust anything about
  /// this package: its own contribution to [EditorReport.projections] is an empty map, not one
  /// left over from whenever it last resolved.
  final bool resolved;
}

/// What `scribe editor` found across every directory it was asked about.
class EditorReport {
  /// Records what was found.
  const EditorReport({required this.packages, required this.conflicts, required this.projections});

  /// Every directory asked about, in the order it was given.
  final List<EditorPackage> packages;

  /// Every conflict a runtime's fold met, keyed by that runtime.
  ///
  /// A runtime absent here folded without disagreement, which is the common case: two packages
  /// answering the same specifier two different ways only happens across two checkouts under one
  /// workspace.
  final Map<String, List<ImportConflict>> conflicts;

  /// What an editor needs to do for each runtime present among [packages], keyed by that runtime.
  final Map<String, EditorProjection> projections;
}

/// Reads what `scribe forge` already left for each of [directories], groups the result by
/// runtime, folds each group, and asks every runtime present what an editor needs.
///
/// Nothing here resolves a package: that is `scribe forge`'s job, and this only reads what it
/// already wrote. A directory whose resolution is missing or unreadable still joins its runtime's
/// group, as an empty contribution, rather than being dropped from it — an editor that asked
/// about it needs to see its share of that runtime's configuration cleared, not left stale from
/// whenever the package last resolved.
///
/// Throws when a directory carries no `package.yaml`, the same refusal [loadManifest] already
/// makes: asking this about something that is not a package is a usage mistake, not a package
/// waiting to be resolved.
EditorReport buildEditorReport(List<String> directories) {
  final List<EditorPackage> packages = <EditorPackage>[];
  final Map<String, List<PackageImports>> imports = <String, List<PackageImports>>{};
  final Map<String, List<String>> groupDirectories = <String, List<String>>{};

  for (final String directory in directories) {
    final Manifest manifest = loadManifest(directory);
    final Map<String, String>? reaches = readResolvedImports(directory);

    packages.add(EditorPackage(directory: directory, runtime: manifest.runtime, resolved: reaches != null));
    imports
        .putIfAbsent(manifest.runtime, () => <PackageImports>[])
        .add(PackageImports(name: manifest.name, reaches: reaches ?? const <String, String>{}));
    groupDirectories.putIfAbsent(manifest.runtime, () => <String>[]).add(directory);
  }

  final Map<String, List<ImportConflict>> conflicts = <String, List<ImportConflict>>{};
  final Map<String, EditorProjection> projections = <String, EditorProjection>{};

  for (final MapEntry<String, List<PackageImports>> group in imports.entries) {
    final List<PackageImports> sorted = group.value.toList()
      ..sort((PackageImports a, PackageImports b) => a.name.compareTo(b.name));
    final ImportFold fold = foldImports(sorted);

    if (fold.conflicts.isNotEmpty) conflicts[group.key] = fold.conflicts;
    projections[group.key] = JsRuntime.named(
      group.key,
    ).editorProjection(fold.imports, directories: groupDirectories[group.key]!);
  }

  return EditorReport(packages: packages, conflicts: conflicts, projections: projections);
}
