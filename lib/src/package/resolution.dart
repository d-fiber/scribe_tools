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
import 'package:scribe_tools/src/package/checks.dart';
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/package/workspace.dart';

/// The specifier the language is imported under.
const String kLanguage = '@scribe/alchemy';

/// The directory a package keeps what was resolved for it in.
const String kResolutionDirectory = '.scribe';

/// The file holding what resolving decided, in our own words.
///
/// It is ours and it is the only thing in [kResolutionDirectory] that is: the
/// checkout that resolved, the package it resolved, and what each specifier the
/// package may write answers to. Nothing in it is shaped for a runtime.
///
/// A package author never opens it and never commits it, because it holds paths
/// that are true on one machine and false on the next.
const String kResolutionFile = 'resolution.json';

/// The directory the tool keeps, under the home of whoever runs it.
///
/// It is where a runtime's own files go, outside every package. See
/// [runtimeHomeOf].
const String kToolDirectory = '.scribe';

/// The directory, inside [kToolDirectory], holding one directory per resolved package.
const String kRuntimesDirectory = 'runtimes';

/// The file a runtime is handed, built from what [kResolutionFile] decided.
///
/// It carries the runtime's name because it sits in the runtime's own house, not
/// in the package. The lock is not named in it: a runtime writes one beside
/// whatever configuration it is given, so naming it would only be a second place
/// for the two to disagree.
const String kRuntimeConfigFile = 'deno.json';

/// Where the runtime's files for the package at [package] are built.
///
/// Nothing a runtime spells belongs in a package. A package carries what it is
/// and what it hands over, and a configuration written in somebody else's
/// vocabulary is neither: it is the by-product of resolving, true on this machine
/// only, and it goes where the tool keeps its own things.
///
/// The directory is named after the package and after where the package sits, so
/// that two checkouts of one package do not resolve into each other. The path is
/// derived and never written down, because a second copy would be a second thing
/// to keep in step.
String runtimeHomeOf(String package) {
  final Map<String, String> read = globals.platform.environment;
  final String home = read['HOME'] ?? read['USERPROFILE'] ?? globals.fs.systemTempDirectory.path;
  final String at = p.absolute(package);

  return p.join(home, kToolDirectory, kRuntimesDirectory, '${p.basename(at)}-${_fingerprintOf(at)}');
}

/// A short, stable mark for [text], the same on every run and on every machine.
///
/// FNV-1a, 32 bits. Dart's own `hashCode` is not promised to hold from one run to
/// the next, and a directory keyed on it would move under a package that never
/// did. What is wanted here is only that two different paths get two different
/// names, which is what this buys for six lines and no dependency.
String _fingerprintOf(String text) {
  int hash = 0x811c9dc5;
  for (final int unit in utf8.encode(text)) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }

  return hash.toRadixString(16).padLeft(8, '0');
}

/// The directory an editor reads its settings from.
const String kEditorDirectory = '.vscode';

/// The file the editor reads its settings from.
const String kEditorSettingsFile = 'settings.json';

/// The setting naming the configuration the language server resolves through.
///
/// The server walks up from the file it is asked about looking for a runtime's own
/// configuration, and a package carries none anywhere: what it resolves through is
/// built outside the package, in [runtimeHomeOf], and handed over by absolute
/// path. Without this the editor reports every specifier as unresolved while the
/// command line type checks the same file clean.
///
/// This name and [kEditorEnableSetting] are the two places a runtime is still
/// spelled out inside a package, and neither is ours to choose: they are the keys
/// the editor extension reads. The file they sit in is generated, ignored by git,
/// and true on one machine only.
const String kEditorConfigSetting = 'deno.config';

/// The setting that turns the language server on for this directory.
const String kEditorEnableSetting = 'deno.enable';

/// What a package needs from outside itself, beyond the language.
///
/// The test harness is the only one so far. It is not a dependency a package
/// declares, for the same reason the language is not: a package that could
/// decline it could not be tested.
///
/// The checkout pins it too, and what the checkout pins wins. This is the floor
/// for a checkout whose map has lost it, so that a package still has something to
/// assert with.
const Map<String, String> kAlwaysResolved = <String, String>{'@std/assert': 'jsr:@std/assert@1'};

/// What resolving a package left behind.
class Resolution {
  /// Records that [directory] was resolved against [sdk], writing [imports].
  const Resolution({required this.directory, required this.sdk, required this.imports});

  /// The path of the directory the resolution was written into.
  final String directory;

  /// The checkout it was resolved against.
  final Sdk sdk;

  /// What each specifier the package may write now answers to.
  final Map<String, String> imports;

  /// The path of the file holding what was decided, in our own words.
  String get file => p.join(directory, kResolutionDirectory, kResolutionFile);

  /// The path of the configuration a command hands to the runtime, outside the package.
  String get runtimeConfig => p.join(runtimeHomeOf(directory), kRuntimeConfigFile);
}

/// Whether [package] has a resolution that was written against [sdk].
///
/// Answers false when nothing was resolved, when what was resolved names another
/// version, and when the file cannot be read at all. All three are the same thing
/// to a caller: it has to resolve again before it can do anything.
bool isResolved(String package, Sdk sdk) {
  final File written = globals.fs.file(p.join(package, kResolutionDirectory, kResolutionFile));
  if (!written.existsSync()) return false;

  try {
    final Object? document = jsonDecode(written.readAsStringSync());
    if (document is! Map<String, Object?>) return false;

    final Object? checkout = document[kEnvironmentKey];
    return checkout is Map<String, Object?> && checkout['version'] == sdk.version;
  } on FormatException {
    return false;
  }
}

/// Resolves the package in [directory] against [sdk], and answers what it left.
///
/// What the package reaches is the checkout's own map, with the package's own
/// directory swapped in for the copy the checkout carries. That way a version of
/// anything outside the framework is pinned in one place, and a package being
/// written outside a checkout reaches exactly what it would reach inside one.
///
/// The manifest is read for three reasons: it refuses a directory that is not a
/// package before anything is written, it gives the name the package reaches its
/// own files under, so that a file may cite a neighbour the way everything else
/// does rather than by counting directories, and it names the framework versions
/// the package accepts.
///
/// That last one is checked here and nowhere else, because this is the one place
/// a package and a checkout meet. A checkout the package refuses would otherwise
/// resolve, and the run would end in a hundred type errors that name files rather
/// than the version that caused them.
///
/// Throws a [ToolExit] when [directory] carries no manifest, when it carries one
/// that cannot be read, when the package fails its own checks, and when [sdk] is
/// not a checkout the package accepts.
Resolution resolve(String directory, Sdk sdk) {
  final Manifest manifest = loadManifest(directory);
  _refuseBroken(manifest, directory);
  _refuseMismatch(manifest, sdk, directory);

  final Map<String, String> imports = <String, String>{
    ...kAlwaysResolved,
    ...sdkImports(sdk),
    ...languageImports(sdk),
    '@scribe/${manifest.name}': Uri.file(p.absolute(p.join(directory, entryOf(manifest.name)))).toString(),
    '@scribe/${manifest.name}/': Uri.directory(p.absolute(directory)).toString(),
  };

  final Directory held = globals.fs.directory(p.join(directory, kResolutionDirectory))..createSync(recursive: true);
  final Directory runtime = globals.fs.directory(runtimeHomeOf(directory))..createSync(recursive: true);

  _write(p.join(held.path, kResolutionFile), <String, Object>{
    'package': manifest.name,
    'entry': entryOf(manifest.name),
    kEnvironmentKey: <String, Object>{'root': p.absolute(sdk.root), 'version': sdk.version},
    'reaches': imports,
  });
  _write(p.join(runtime.path, kRuntimeConfigFile), <String, Object>{'imports': imports});
  _pointEditorAtResolution(directory);

  return Resolution(directory: p.absolute(directory), sdk: sdk, imports: imports);
}

void _write(String path, Map<String, Object> document) =>
    globals.fs.file(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(document)}\n');

/// Stops before writing anything when the package does not hold together.
///
/// Reading the manifest catches what the text gets wrong, a name, a version, a
/// path that climbs out of the package. It cannot catch what the text and the
/// tree disagree on, and that is most of it: a declared directory that is not
/// there, an ops entry that holds no fragment, a missing entry file. Left to the
/// resolution, all of those are written down as if they were true, and the
/// package is mounted somewhere before anybody finds out.
void _refuseBroken(Manifest manifest, String directory) {
  final List<Problem> problems = problemsWithin(
    DiscoveredPackage(manifest: manifest, directory: p.absolute(directory)),
  );
  if (problems.isEmpty) return;

  throwToolExit(
    '${manifest.name} does not hold together, so nothing was resolved:\n'
    '${problems.map((Problem problem) => '  ${problem.message}').join('\n')}',
  );
}

void _refuseMismatch(Manifest manifest, Sdk sdk, String directory) {
  if (allows(manifest.scribe, sdk.version)) return;

  throwToolExit(
    '${manifest.name} accepts scribe ${manifest.scribe}, and the checkout at ${sdk.root} '
    'publishes ${sdk.version}.\n'
    'Point $kSdkRootVariable at a checkout it accepts, or widen "environment.$kEnvironmentKey:" '
    'in ${p.join(directory, kManifestFile)} once you have run the suite against this one.',
  );
}

/// Tells the editor in [directory] to resolve through what was just written.
///
/// Whatever else the file held is kept. It is ignored by git and generated by
/// this, but a person still puts their own settings in it, and a command that
/// dropped them would cost more than the two lines it came to write.
void _pointEditorAtResolution(String directory) {
  final File settings = globals.fs.file(p.join(directory, kEditorDirectory, kEditorSettingsFile));
  final Map<String, Object?> held = settings.existsSync() ? _settingsIn(settings) : <String, Object?>{};

  held[kEditorEnableSetting] = true;
  held[kEditorConfigSetting] = p.join(runtimeHomeOf(directory), kRuntimeConfigFile);

  settings.parent.createSync(recursive: true);
  settings.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(held)}\n');
}

Map<String, Object?> _settingsIn(File settings) {
  try {
    final Object? document = jsonDecode(settings.readAsStringSync());
    return document is Map<String, Object?> ? document : <String, Object?>{};
  } on FormatException {
    return <String, Object?>{};
  }
}

/// Every entry the language publishes, from the specifier to the file it answers.
///
/// The list is read from the language's own manifest rather than written here,
/// because a package reaches what the language publishes and only the language
/// knows what that is. Writing one entry and leaving the rest out is what made
/// six of its seven unreachable, so a package that imported one of them failed to
/// resolve while the command line reported nothing.
///
/// Throws a [ToolExit] when the checkout carries no manifest for the language, or
/// one that names no exports.
Map<String, String> languageImports(Sdk sdk) {
  final File manifest = globals.fs.file(p.join(sdk.alchemyRoot, 'deno.json'));
  if (!manifest.existsSync()) {
    throwToolExit('The checkout at ${sdk.root} carries no ${manifest.path}, so $kLanguage cannot be resolved.');
  }

  final Object? document = jsonDecode(manifest.readAsStringSync());
  final Object? exports = document is Map<String, Object?> ? document['exports'] : null;
  if (exports is! Map<String, Object?>) {
    throwToolExit('${manifest.path} names no "exports", so $kLanguage publishes nothing to resolve.');
  }

  final Map<String, String> imports = <String, String>{};
  for (final MapEntry<String, Object?> entry in exports.entries) {
    final Object? file = entry.value;
    if (file is! String) continue;

    final String specifier = entry.key == '.' ? kLanguage : '$kLanguage/${entry.key.substring(2)}';
    imports[specifier] = Uri.file(p.normalize(p.join(sdk.alchemyRoot, file))).toString();
  }

  return imports;
}
