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

import 'dart:convert';

import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/forge/protocol/declared_proto_contract.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';
import 'package:scribe_tools/src/templates.dart';

/// The bridge script this tool ships, relative to its own `scripts/` — see
/// `schema_bridge_process.dart`'s own `kBridgeScriptPathSegments` for why it lives there rather
/// than inside the checkout it runs against.
const List<String> kProtocolBridgeScriptPathSegments = <String>['protocol', 'protocol_bridge.ts'];

/// Every `.ts` file under [protocolDirectory], sorted, which is the order the bridge imports them in.
List<File> protocolSourceFiles(Directory protocolDirectory) {
  if (!protocolDirectory.existsSync()) return const <File>[];

  final List<File> found = protocolDirectory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.ts'))
      .toList();

  return found..sort((File a, File b) => a.path.compareTo(b.path));
}

/// The contracts declared by importing [sourceFiles] under [runtime], resolved against [resolution].
///
/// Throws a [ToolExit] when the bridge leaves with a failure — two `@Proto` classes sharing a name,
/// or two messages sharing a name inside the same one, are the cases this is written for, and the
/// message is [runtime]'s own, relayed as it printed it.
Future<List<DeclaredProtoContract>> runProtocolBridge({
  required List<File> sourceFiles,
  required Resolution resolution,
  required JsRuntime runtime,
}) async {
  final File bridge = globals.templatePaths
      .root(globals.fs)
      .childDirectory(kScriptsDirectoryName)
      .childDirectory(kProtocolBridgeScriptPathSegments[0])
      .childFile(kProtocolBridgeScriptPathSegments[1]);

  if (!bridge.existsSync()) {
    throwToolExit(
      '${bridge.path} is missing. This tool ships it next to its binary, so an installation that '
      'never unpacked $kScriptsDirectoryName/${p.joinAll(kProtocolBridgeScriptPathSegments)} cannot '
      'generate .proto from a protocol/.',
    );
  }

  final ShellResult output = await runtime.runScript(
    bridge.path,
    scriptArgs: sourceFiles.map((File source) => source.path).toList(),
    imports: resolution.imports,
  );

  if (output.error.isNotEmpty) globals.logger.printWarning(output.error);

  if (output.failed) {
    throwToolExit('the protocol bridge failed under ${runtime.name}, exit code ${output.exitCode}.');
  }

  return (jsonDecode(output.stdout) as List<dynamic>)
      .map((dynamic entry) => DeclaredProtoContract.fromJson(entry as Map<String, dynamic>))
      .toList();
}
