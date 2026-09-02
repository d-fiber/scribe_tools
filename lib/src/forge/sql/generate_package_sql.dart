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
import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';
import 'package:scribe_tools/src/forge/sql/emit_sql.dart';
import 'package:scribe_tools/src/forge/sql/schema_bridge_process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';

/// What forging a package's `schema/` into SQL produced.
class GeneratedSqlReport {
  /// Holds where the SQL was written and what it holds, as `scribe forge` reports it.
  const GeneratedSqlReport({
    required this.file,
    required this.enumCount,
    required this.compositeTypeCount,
    required this.tableCount,
    required this.functionCount,
    required this.triggerCount,
    required this.cronJobCount,
  });

  /// The file that was written, relative to the package.
  final String file;

  /// How many enums it declares.
  final int enumCount;

  /// How many composite types it declares.
  final int compositeTypeCount;

  /// How many tables it declares.
  final int tableCount;

  /// How many functions it declares.
  final int functionCount;

  /// How many triggers it declares.
  final int triggerCount;

  /// How many scheduled jobs it declares.
  final int cronJobCount;
}

/// Rebuilds [directory]'s `deploy/$kDatabaseDirectory/init/$kGeneratedSchemaFile` from its
/// `$kSchemaDirectory/`, resolved against [resolution].
///
/// Answers null and writes nothing when the package carries no `$kSchemaDirectory/`, or one
/// holding no `$kSchemaSuffix` file: a package that hand-writes its own SQL has nothing here to
/// generate, and forging it must leave that SQL exactly as it was.
///
/// The file is rebuilt whole, never patched, the same choice `scribe gen docs` makes for the
/// documents it owns — a partial regeneration would leave stale tables behind with nothing to
/// say they no longer come from `$kSchemaDirectory/`.
Future<GeneratedSqlReport?> generatePackageSql(String directory, Resolution resolution) async {
  final Directory schemaDirectory = globals.fs.directory(p.join(directory, kSchemaDirectory));
  final List<File> sourceFiles = schemaSourceFiles(schemaDirectory);
  if (sourceFiles.isEmpty) return null;

  final File manifestFile = globals.fs.file(p.join(directory, kManifestFile));
  final Manifest manifest = Manifest.parse(manifestFile.readAsStringSync(), manifestFile.path);
  final JsRuntime runtime = JsRuntime.named(manifest.runtime);

  final DeclaredSqlSchema schema = await runSchemaBridge(
    sourceFiles: sourceFiles,
    resolution: resolution,
    runtime: runtime,
  );

  final File output = globals.fs.file(
    p.join(directory, kDeployDirectory, kDatabaseDirectory, 'init', kGeneratedSchemaFile),
  );
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(emitSql(packageName: manifest.name, schema: schema));

  return GeneratedSqlReport(
    file: p.relative(output.path, from: directory),
    enumCount: schema.enums.length,
    compositeTypeCount: schema.compositeTypes.length,
    tableCount: schema.tables.length,
    functionCount: schema.functions.length,
    triggerCount: schema.triggers.length,
    cronJobCount: schema.cronJobs.length,
  );
}
