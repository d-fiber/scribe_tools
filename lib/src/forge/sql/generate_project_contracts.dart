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
import 'package:scribe_tools/src/forge/sql/generate_contracts.dart';
import 'package:scribe_tools/src/forge/sql/generate_package_sql.dart';
import 'package:scribe_tools/src/forge/sql/schema_bridge_process.dart';
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';

/// What generating every mounted package's TypeScript contracts into a project produced.
class GeneratedProjectContractsReport {
  /// Holds the files [generateProjectContracts] wrote, and the packages it left out.
  const GeneratedProjectContractsReport({required this.files, required this.skipped});

  /// The contracts files written, relative to the project, one per package that had something to
  /// declare and a resolution already written to read.
  final List<String> files;

  /// The name of every mounted package that carries a `schema/` but was left out because it has
  /// never been forged itself: nothing under its own `.scribe/` names what it reaches, and nothing
  /// here resolves it, since that would write into a checkout this run does not own.
  final List<String> skipped;
}

/// Writes `$kContractsRootDirectory/$kContractsDirectory/<name>.ts` under [project]'s own
/// directory, one file per package of [mounted] that carries a `$kSchemaDirectory/`.
///
/// A mounted package's own import map is read from its `.scribe/resolution.json`, written the last
/// time that package was itself forged — never recomputed here with `resolve()`, which writes a
/// fresh resolution and a `package.lock` into whatever directory it is given: calling it on a
/// mounted package's own checkout from a project's forge would rewrite files that belong to that
/// package's own repository, not to this project. A package with no resolution file yet is named
/// in [GeneratedProjectContractsReport.skipped] instead of read.
Future<GeneratedProjectContractsReport> generateProjectContracts(Project project, List<Package> mounted) async {
  final List<String> files = <String>[];
  final List<String> skipped = <String>[];
  final Sdk sdk = findSdk(from: project.sdk.path);

  for (final Package package in mounted) {
    final String directory = package.directory.path;
    if (schemaSourceFiles(package.directory.childDirectory(kSchemaDirectory)).isEmpty) continue;

    final Map<String, String>? imports = readResolvedImports(directory);
    if (imports == null) {
      skipped.add(package.name);
      continue;
    }

    final DeclaredPackageSchema? declared = await declaredPackageSchema(
      directory,
      Resolution(directory: directory, sdk: sdk, imports: imports),
    );
    if (declared == null) continue;

    final File? file = writeContracts(
      rootDirectory: project.directory.path,
      packageName: declared.packageName,
      schema: declared.schema,
    );
    if (file != null) files.add(p.relative(file.path, from: project.directory.path));
  }

  return GeneratedProjectContractsReport(files: files, skipped: skipped);
}
