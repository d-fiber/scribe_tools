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
import 'package:scribe_tools/src/forge/sql/generate_contracts.dart';
import 'package:scribe_tools/src/forge/sql/schema_bridge_process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';

/// What forging a package's `schema/` into SQL produced for one moment, one entry per file
/// actually written — a moment with nothing declared for it writes no file, and carries no entry.
class GeneratedSqlMomentReport {
  /// Holds where this moment's SQL was written and what it holds, as `scribe forge` reports it.
  const GeneratedSqlMomentReport({
    required this.moment,
    required this.file,
    required this.tableCount,
    required this.indexCount,
    required this.policyCount,
    required this.grantCount,
    required this.sequenceCount,
    required this.enumCount,
    required this.compositeTypeCount,
    required this.extensionCount,
    required this.dropCount,
  });

  /// Which of `init`, `migrations` or `provisioning` this is.
  final String moment;

  /// The file that was written, relative to the package.
  final String file;

  /// How many tables it declares.
  final int tableCount;

  /// How many indexes it declares.
  final int indexCount;

  /// How many row-level security policies it declares.
  final int policyCount;

  /// How many privilege grants it declares.
  final int grantCount;

  /// How many standalone sequences it declares.
  final int sequenceCount;

  /// How many enums it declares.
  final int enumCount;

  /// How many composite types it declares.
  final int compositeTypeCount;

  /// How many extensions it declares.
  final int extensionCount;

  /// How many retirements it declares.
  final int dropCount;
}

/// What forging a package's `schema/` into SQL produced.
class GeneratedSqlReport {
  /// Holds one report per moment a file was actually written for, plus the enums and composite
  /// types declared across the three moments together.
  const GeneratedSqlReport({
    required this.enumCount,
    required this.compositeTypeCount,
    required this.moments,
    required this.contractsFile,
  });

  /// How many enums the package declares, across every moment.
  final int enumCount;

  /// How many composite types the package declares, across every moment.
  final int compositeTypeCount;

  /// One report per moment a file was actually written for, in the order `kDatabaseMoments` lists them.
  final List<GeneratedSqlMomentReport> moments;

  /// The TypeScript contracts file written alongside the SQL, relative to the package. Null when
  /// `writeContracts` had nothing to say — no enum, no composite type, no table at all.
  final String? contractsFile;
}

/// A package's own name, alongside the schema its `$kSchemaDirectory/` declared.
class DeclaredPackageSchema {
  /// Holds [packageName] and the [schema] the bridge read off its `$kSchemaDirectory/`.
  const DeclaredPackageSchema({required this.packageName, required this.schema});

  /// The name this package qualifies its own SQL with, read from its manifest.
  final String packageName;

  /// The schema the bridge read off this package's `$kSchemaDirectory/`.
  final DeclaredSqlSchema schema;
}

/// The schema `directory`'s own `$kSchemaDirectory/` declares, resolved against [resolution].
///
/// Null when the package carries no `$kSchemaDirectory/`, or one holding no `$kSchemaSuffix` file:
/// a package that hand-writes its own SQL has nothing here to read.
///
/// Shared by `generatePackageSql`, in package mode, and `generateProjectContracts`, which reads it
/// for every package a project mounts — both want the same two things, this package's own name and
/// what its `schema/` declares, and neither wants to run the bridge itself.
Future<DeclaredPackageSchema?> declaredPackageSchema(String directory, Resolution resolution) async {
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

  return DeclaredPackageSchema(packageName: manifest.name, schema: schema);
}

/// Rebuilds [directory]'s `deploy/$kDatabaseDirectory/<moment>/$kGeneratedSchemaFile`, one file per
/// moment declared for, and its `$kContractsRootDirectory/$kContractsDirectory/` TypeScript
/// contracts, from its `$kSchemaDirectory/`, resolved against [resolution].
///
/// Answers null and writes nothing when the package carries no `$kSchemaDirectory/`, or one
/// holding no `$kSchemaSuffix` file: a package that hand-writes its own SQL has nothing here to
/// generate, and forging it must leave that SQL exactly as it was.
///
/// Each file is rebuilt whole, never patched, the same choice `scribe gen docs` makes for the
/// documents it owns — a partial regeneration would leave stale tables behind with nothing to say
/// they no longer come from `$kSchemaDirectory/`. A moment nothing was declared for keeps whatever
/// it already carried by hand: this only ever writes the one file it owns, `$kGeneratedSchemaFile`,
/// and only when there is something to put in it.
Future<GeneratedSqlReport?> generatePackageSql(String directory, Resolution resolution) async {
  final DeclaredPackageSchema? declared = await declaredPackageSchema(directory, resolution);
  if (declared == null) return null;
  final DeclaredSqlSchema schema = declared.schema;

  final EmittedSql emitted = emitSql(packageName: declared.packageName, schema: schema);
  final List<GeneratedSqlMomentReport> moments = <GeneratedSqlMomentReport>[
    if (emitted.init != null) _writeMoment(directory, 'init', emitted.init!, schema.init),
    if (emitted.migrations != null) _writeMoment(directory, 'migrations', emitted.migrations!, schema.migrations),
    if (emitted.provisioning != null)
      _writeMoment(directory, 'provisioning', emitted.provisioning!, schema.provisioning),
  ];

  final File? contracts = writeContracts(rootDirectory: directory, packageName: declared.packageName, schema: schema);

  return GeneratedSqlReport(
    enumCount: schema.init.enums.length + schema.migrations.enums.length + schema.provisioning.enums.length,
    compositeTypeCount:
        schema.init.compositeTypes.length +
        schema.migrations.compositeTypes.length +
        schema.provisioning.compositeTypes.length,
    moments: moments,
    contractsFile: contracts == null ? null : p.relative(contracts.path, from: directory),
  );
}

GeneratedSqlMomentReport _writeMoment(String directory, String moment, String sql, DeclaredSqlMoment declared) {
  final File output = globals.fs.file(
    p.join(directory, kDeployDirectory, kDatabaseDirectory, moment, kGeneratedSchemaFile),
  );
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(sql);

  return GeneratedSqlMomentReport(
    moment: moment,
    file: p.relative(output.path, from: directory),
    tableCount: declared.tables.length,
    indexCount: declared.indexes.length,
    policyCount: declared.policies.length,
    grantCount: declared.grants.length,
    sequenceCount: declared.sequences.length,
    enumCount: declared.enums.length,
    compositeTypeCount: declared.compositeTypes.length,
    extensionCount: declared.extensions.length,
    dropCount: declared.drops.length,
  );
}
