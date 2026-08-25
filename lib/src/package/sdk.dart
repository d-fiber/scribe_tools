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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/sdk_target.dart';

/// The file the checkout carries its version in.
///
/// It is the workspace root's own configuration: scribe is one Deno project, and a
/// Deno project says its version there. There is no `VERSION` file any more, and
/// nothing else in the checkout names the version.
const String kSdkVersionFile = 'deno.json';

/// The file the checkout declares what every specifier answers to in.
///
/// It is the runtime's own configuration, and the one place a version of anything
/// outside the framework is pinned. A package resolves through it rather than
/// pinning its own, so that two packages cannot disagree on which redis client
/// they got.
const String kSdkImportMapFile = 'deno.json';

/// The directory, inside a checkout, holding the language a package is written against.
const String kAlchemyDirectory = 'engine/alchemy';

/// The variable that names the checkout when nothing else can find it.
const String kSdkRootVariable = 'SCRIBE_ROOT';

/// The version a checkout carrying no readable `VERSION` is treated as publishing.
///
/// Nothing accepts it: every constraint a package writes names three numbers, so
/// a checkout that answers this is refused by the first package resolved against
/// it, and the refusal names the version rather than the hundred type errors that
/// would otherwise follow.
const String kUnknownVersion = 'unknown';

/// A framework checkout on this machine, as a package resolves against it.
///
/// It is a value and not a live view: [root] and [version] are read once, and
/// nothing here reaches git. Moving a checkout between versions is `Framework`,
/// in `framework.dart`, and the two are apart because a package is resolved far
/// more often than a checkout is moved.
class Sdk {
  /// Records the checkout at [root], publishing [version].
  const Sdk({required this.root, required this.version});

  /// The path of the checkout.
  final String root;

  /// The version the checkout publishes, read from its `VERSION` file.
  final String version;

  /// The path of the language a package is written against.
  String get alchemy => p.join(alchemyRoot, 'mod.ts');

  /// The directory the language lives in, which is what carries its entries.
  String get alchemyRoot => p.join(root, p.joinAll(p.posix.split(kAlchemyDirectory)));
}

/// The checkout this run should resolve a package against.
///
/// Three places are tried, in this order: the variable [kSdkRootVariable], the
/// directories above [from], and the directories above this program. The middle
/// one is what answers for a package written inside a checkout, and the last is
/// what answers for the tool a checkout installed.
///
/// What counts as a checkout is [SdkCatalog.isFrameworkRoot], the same answer
/// `create`, `upgrade` and `doctor` get, so no two commands can disagree about
/// which directory they are looking at.
///
/// Throws a [ToolExit] when none of the three holds a checkout.
Sdk findSdk({String? from}) {
  final String? named = globals.platform.environment[kSdkRootVariable];
  if (named != null && named.isNotEmpty) {
    final Sdk? held = _sdkAt(globals.fs.directory(named));
    if (held != null) return held;
    throwToolExit('$kSdkRootVariable names $named, which is not a scribe checkout.');
  }

  final String start = from ?? globals.fs.currentDirectory.path;
  for (final String above in <String>[start, _programDirectory()]) {
    final Directory? found = SdkCatalog.findFrameworkRoot(globals.fs.directory(above));
    if (found == null) continue;

    final Sdk? held = _sdkAt(found);
    if (held != null) return held;
  }

  throwToolExit(
    'No scribe checkout above $start or above this program.\n'
    'Point $kSdkRootVariable at one, or run this from inside a checkout.',
  );
}

Sdk? _sdkAt(Directory root) {
  if (!SdkCatalog.isFrameworkRoot(root)) return null;

  return Sdk(root: p.absolute(root.path), version: _versionOf(root));
}

/// The version the checkout at [root] publishes, or [kUnknownVersion].
///
/// It is read from the workspace root's own `deno.json`, which is where a Deno
/// project carries its version. A checkout whose file is missing, unreadable or
/// silent about the version answers [kUnknownVersion], which every constraint a
/// package writes refuses, so the refusal names the version instead of the
/// hundred type errors that would otherwise follow.
String _versionOf(Directory root) {
  final File map = root.childFile(kSdkVersionFile);
  if (!map.existsSync()) return kUnknownVersion;

  try {
    final Object? document = jsonDecode(map.readAsStringSync());
    if (document is! Map<String, Object?>) return kUnknownVersion;

    final Object? version = document['version'];
    return version is String && version.isNotEmpty ? version : kUnknownVersion;
  } on FormatException {
    return kUnknownVersion;
  }
}

String _programDirectory() {
  final File program = globals.fs.file(globals.platform.resolvedExecutable);
  final String resolved = program.existsSync() ? program.resolveSymbolicLinksSync() : program.path;
  return p.dirname(resolved);
}

/// What every specifier answers to inside [sdk], with its paths made absolute.
///
/// The paths in the checkout's own map are relative to the file that holds it, so
/// they mean nothing once the map is written somewhere else. Everything that is
/// already a registry specifier is carried over untouched.
///
/// Throws a [ToolExit] when the checkout carries no map, or one that cannot be
/// read.
Map<String, String> sdkImports(Sdk sdk) {
  final File map = globals.fs.file(p.join(sdk.root, p.joinAll(p.posix.split(kSdkImportMapFile))));
  if (!map.existsSync()) {
    throwToolExit('The checkout at ${sdk.root} carries no $kSdkImportMapFile, so nothing can be resolved through it.');
  }

  final Object? document = _decode(map);
  if (document is! Map<String, Object?>) {
    throwToolExit('${map.path} is not a mapping, so nothing can be resolved through it.');
  }

  final Object? imports = document['imports'];
  if (imports == null) return const <String, String>{};
  if (imports is! Map<String, Object?>) {
    throwToolExit('${map.path} holds "imports" as something other than a block of specifiers.');
  }

  final String beside = map.parent.path;
  final Map<String, String> held = <String, String>{};
  imports.forEach((String specifier, Object? answer) {
    if (answer is! String) return;
    held[specifier] = _absolute(answer, beside);
  });

  held.addAll(_layersOf(sdk));

  return held;
}

/// The directory, inside a checkout, holding the framework's own layers.
const String kLayersDirectory = 'engine';

/// Every layer the checkout publishes, from its specifier to its directory.
///
/// The root map does not name them, and that is deliberate: a workspace member
/// inherits what the root declares, so a layer written there would be reachable
/// from every other one and the order between them would stop being enforced.
/// Each layer declares itself in its own `deno.json` instead.
///
/// A package resolved outside a checkout still has to reach them, so they are
/// read back from the tree here. A directory counts as a layer when it carries a
/// `deno.json`, which is what makes it a member.
Map<String, String> _layersOf(Sdk sdk) {
  final Directory layers = globals.fs.directory(p.join(sdk.root, kLayersDirectory));
  if (!layers.existsSync()) return const <String, String>{};

  final Map<String, String> found = <String, String>{};
  for (final FileSystemEntity entry in layers.listSync()) {
    if (entry is! Directory) continue;
    if (!globals.fs.file(p.join(entry.path, 'deno.json')).existsSync()) continue;

    found['@scribe/${p.basename(entry.path)}/'] = '${p.absolute(entry.path)}/';
  }

  return found;
}

Object? _decode(File map) {
  try {
    return jsonDecode(map.readAsStringSync());
  } on FormatException catch (error) {
    throwToolExit('${map.path} is not readable as JSON: ${error.message}');
  }
}

String _absolute(String answer, String beside) {
  if (!answer.startsWith('./') && !answer.startsWith('../')) return answer;

  final String path = p.normalize(p.join(beside, answer));
  return answer.endsWith('/') ? Uri.directory(path).toString() : Uri.file(path).toString();
}
