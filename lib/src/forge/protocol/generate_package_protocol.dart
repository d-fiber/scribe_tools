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
import 'package:scribe_tools/src/forge/protocol/declared_proto_contract.dart';
import 'package:scribe_tools/src/forge/protocol/emit_proto.dart';
import 'package:scribe_tools/src/forge/protocol/protocol_bridge_process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';

/// What forging one `@Proto(...)` class produced.
class GeneratedProtoFileReport {
  /// Holds where one contract's `.proto` was written and what it declares.
  const GeneratedProtoFileReport({
    required this.contract,
    required this.file,
    required this.messageCount,
    required this.enumCount,
    required this.serviceCount,
  });

  /// The class name this file was rendered from.
  final String contract;

  /// The file that was written, relative to the package.
  final String file;

  /// How many messages it declares.
  final int messageCount;

  /// How many enums it declares.
  final int enumCount;

  /// How many services it declares.
  final int serviceCount;
}

/// What forging a package's `protocol/` into `.proto` produced.
class GeneratedProtoReport {
  /// Holds one file report per `@Proto(...)` class the bridge found.
  const GeneratedProtoReport({required this.files});

  /// One entry per contract a `.proto` file was written for, in the order the bridge declared them.
  final List<GeneratedProtoFileReport> files;
}

/// Rebuilds [directory]'s `$kResolutionDirectory/$kGenDirectory/$kGenProtocolDirectory/`, one
/// `.proto` file per `@Proto(...)` class found under its `$kProtocolDirectory/`, resolved against
/// [resolution].
///
/// Answers null and writes nothing when `$kProtocolDirectory/` carries no `.ts` file at all: a
/// package whose `protocol/` is hand-written `.proto` only has nothing here to render, the same
/// way `generatePackageSql` answers null for a package that hand-writes its SQL. A hand-written
/// `.proto` is left exactly where it is — nothing here copies or touches it.
///
/// The whole output directory is wiped and rewritten on every call, never patched: a `@Proto` class
/// renamed or removed must not leave a stale `.proto` behind with nothing to say it no longer comes
/// from `protocol/`, the same reasoning `generatePackageSql`'s own doc gives for
/// `$kGeneratedSchemaFile`. Nothing under `deploy/` is read or written here — this is additive,
/// alongside it, never a replacement for it.
Future<GeneratedProtoReport?> generatePackageProtocol(String directory, Resolution resolution) async {
  final Directory protocolDirectory = globals.fs.directory(p.join(directory, kProtocolDirectory));
  final List<File> sourceFiles = protocolSourceFiles(protocolDirectory);
  if (sourceFiles.isEmpty) return null;

  final File manifestFile = globals.fs.file(p.join(directory, kManifestFile));
  final Manifest manifest = Manifest.parse(manifestFile.readAsStringSync(), manifestFile.path);
  final JsRuntime runtime = JsRuntime.named(manifest.runtime);

  final List<DeclaredProtoContract> contracts = await runProtocolBridge(
    sourceFiles: sourceFiles,
    resolution: resolution,
    runtime: runtime,
  );

  final Directory outputDirectory = globals.fs.directory(
    p.join(directory, kResolutionDirectory, kGenDirectory, kGenProtocolDirectory),
  );
  if (outputDirectory.existsSync()) outputDirectory.deleteSync(recursive: true);
  outputDirectory.createSync(recursive: true);

  final List<GeneratedProtoFileReport> files = <GeneratedProtoFileReport>[];
  for (final DeclaredProtoContract contract in contracts) {
    final EmittedProtoFile emitted = emitProtoContract(packageName: manifest.name, contract: contract);
    final File output = globals.fs.file(p.join(outputDirectory.path, emitted.fileName))
      ..writeAsStringSync(emitted.text);

    files.add(
      GeneratedProtoFileReport(
        contract: contract.name,
        file: p.relative(output.path, from: directory),
        messageCount: contract.messages.length,
        enumCount: contract.enums.length,
        serviceCount: contract.services.length,
      ),
    );
  }

  return GeneratedProtoReport(files: files);
}
