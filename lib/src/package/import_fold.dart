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

/// One package's contribution to a fold: its name, for [ImportConflict.by], and what it reaches.
class PackageImports {
  /// Records what [name] reaches.
  const PackageImports({required this.name, required this.reaches});

  /// The package this contribution came from.
  final String name;

  /// Every specifier this package may write, and what it answers to.
  final Map<String, String> reaches;
}

/// A specifier two packages answered differently while folding.
class ImportConflict {
  /// Records that [by] disagreed with an earlier package on what [specifier] answers to.
  const ImportConflict({required this.specifier, required this.kept, required this.dropped, required this.by});

  /// The specifier the two packages disagree on.
  final String specifier;

  /// The answer kept, from the first package the fold met.
  final String kept;

  /// The answer dropped.
  final String dropped;

  /// The package whose answer was dropped.
  final String by;
}

/// What folding a set of packages' [PackageImports] into one map produced.
class ImportFold {
  /// Records what folding left behind.
  const ImportFold({required this.imports, required this.conflicts});

  /// The map every package folded reaches through, one entry per specifier any of them may write.
  final Map<String, String> imports;

  /// Every specifier two packages answered differently, kept in the order the fold met them.
  final List<ImportConflict> conflicts;
}

/// The import map every package in [packages] reaches through, folded into one.
///
/// Every package answering to one specifier the same way is the common case and folds without a
/// conflict. The first answer a specifier meets is kept; a later package disagreeing on it is
/// reported rather than silently overwriting the first. The order of [packages] decides which
/// answer wins, so a caller sorts them by name before calling this to keep the result the same
/// from one run to the next.
ImportFold foldImports(List<PackageImports> packages) {
  final Map<String, String> imports = <String, String>{};
  final List<ImportConflict> conflicts = <ImportConflict>[];

  for (final PackageImports package in packages) {
    for (final MapEntry<String, String> entry in package.reaches.entries) {
      final String? kept = imports[entry.key];
      if (kept == null) {
        imports[entry.key] = entry.value;
        continue;
      }
      if (kept != entry.value) {
        conflicts.add(ImportConflict(specifier: entry.key, kept: kept, dropped: entry.value, by: package.name));
      }
    }
  }

  final List<String> sortedKeys = imports.keys.toList()..sort();
  return ImportFold(
    imports: <String, String>{for (final String key in sortedKeys) key: imports[key]!},
    conflicts: conflicts,
  );
}
