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

/// The directory, inside a checkout, holding the packages it carries.
const String kPackagesDirectory = 'packages';

/// The specifiers a package named [name] at [directory] is reached through.
///
/// Four surfaces and no fifth: the door, the harness another suite stands it up
/// with, the settings that harness installs at import, and the stack its
/// end-to-end suites share. There is deliberately no entry ending in a slash,
/// because one would let a caller import any file under the package and make the
/// door a suggestion. A package reaches its own files that way, and only its own.
Map<String, String> _doorsOf(String name, String directory) => <String, String>{
  '@scribe/$name': Uri.file(p.absolute(p.join(directory, entryOf(name)))).toString(),
  '@scribe/$name/testing': Uri.file(p.absolute(p.join(directory, kHarnessEntry))).toString(),
  '@scribe/$name/testing/settings': Uri.file(p.absolute(p.join(directory, kHarnessSettings))).toString(),
  '@scribe/$name/e2e': Uri.file(p.absolute(p.join(directory, kE2eStack))).toString(),
};

/// What a package asked for and could not be given, in the sentence a caller prints.
class Unresolved {
  /// Records that [name] could not be answered, for [reason].
  const Unresolved(this.name, this.reason);

  /// The name the manifest wrote.
  final String name;

  /// Why nothing could be put behind it.
  final String reason;

  @override
  String toString() => '"$name": $reason';
}

/// Where a package called [name] is, or null when nowhere holds one.
///
/// Two places are tried, in this order: beside [directory], which is the workspace
/// the package being resolved is written in, and the checkout's own
/// [kPackagesDirectory]. The neighbour comes first so that two packages edited
/// together see each other's working tree rather than the copy a checkout was last
/// given, which is what a workspace is for.
///
/// A directory whose manifest calls itself something else is not a match. The name
/// a package is reached under is the one it declares, and answering the directory
/// would put a package behind a specifier that names another.
String? directoryOfPackage(String name, String directory, Sdk sdk) {
  final List<String> tried = <String>[
    p.join(p.dirname(p.absolute(directory)), name),
    p.join(sdk.root, kPackagesDirectory, name),
  ];

  for (final String held in tried) {
    final File manifest = globals.fs.file(p.join(held, kManifestFile));
    if (!manifest.existsSync()) continue;
    if (Manifest.parse(manifest.readAsStringSync(), manifest.path).name != name) continue;

    return held;
  }

  return null;
}

/// Every package [manifest] reaches, its dependencies' own dependencies included.
///
/// The walk is breadth first over what each manifest declares, and a name already
/// answered is not walked twice, so a diamond costs one visit and a cycle
/// terminates. What comes back is keyed by name because that is what a specifier
/// carries; two directories claiming one name is a problem [problems] reports
/// rather than a pick this makes quietly.
///
/// What a manifest's dev dependencies hold is walked for the package being resolved
/// and for nothing else. A consumer does not run somebody else's suite, so what
/// that suite needed stops at the package that wrote it.
///
/// [external] comes back holding every specifier the walk met, the ones declared by
/// the packages reached included. A map answers one graph and not one package: a
/// file of a dependency is compiled with the package that reached it, so a
/// specifier only that dependency names still has to be in the map, or the check
/// fails inside a package whose own manifest was right all along.
Map<String, String> packageClosure(
  Manifest manifest,
  String directory,
  Sdk sdk,
  Map<String, String> external,
  List<Unresolved> problems,
) {
  final Map<String, String> found = <String, String>{};
  final List<MapEntry<Manifest, String>> pending = <MapEntry<Manifest, String>>[
    MapEntry<Manifest, String>(manifest, p.absolute(directory)),
  ];

  bool first = true;
  while (pending.isNotEmpty) {
    final MapEntry<Manifest, String> held = pending.removeAt(0);
    final Map<String, String> asked = <String, String>{
      ...held.key.dependencies,
      if (first) ...held.key.devDependencies,
    };
    first = false;

    asked.forEach((String name, String constraint) {
      if (constraint == kAny) {
        external.putIfAbsent(name, () => constraint);
        return;
      }
      if (found.containsKey(name) || name == manifest.name) return;

      final String? at = directoryOfPackage(name, held.value, sdk);
      if (at == null) {
        problems.add(
          Unresolved(
            name,
            '${held.key.name} depends on it, and no package of that name sits beside '
            '${p.dirname(held.value)} or in ${p.join(sdk.root, kPackagesDirectory)}.',
          ),
        );
        return;
      }

      final Manifest reached = loadManifest(at);
      if (!allows(constraint, reached.version)) {
        problems.add(
          Unresolved(name, '${held.key.name} accepts $constraint, and the copy at $at publishes ${reached.version}.'),
        );
        return;
      }

      found[name] = at;
      pending.add(MapEntry<Manifest, String>(reached, at));
    });
  }

  return found;
}

/// What every specifier [asked] names answers to, taken from what the checkout pins.
///
/// A package writes the name and never the version, so this is a lookup and not a
/// solve: the checkout's map is the one place a version of anything outside the
/// framework is decided, and a package naming a second one would be a second place
/// for the two to disagree.
///
/// A specifier the checkout does not pin is reported rather than dropped. Dropping
/// it would leave the package to fail at type check, where nothing points back at
/// the line that asked for it.
Map<String, String> externalImports(
  Map<String, String> asked,
  Sdk sdk,
  Map<String, String> pinned,
  List<Unresolved> problems,
) {
  final Map<String, String> imports = <String, String>{};

  asked.forEach((String specifier, String constraint) {
    if (constraint != kAny) return;

    final String? answer = pinned[specifier];
    if (answer == null) {
      problems.add(
        Unresolved(
          specifier,
          'nothing in ${p.join(sdk.root, kSdkImportMapFile)} answers it, so the checkout does not carry it. '
          'Add it there first, where its version is pinned for everybody.',
        ),
      );
      return;
    }

    imports[specifier] = answer;
  });

  return imports;
}

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

/// Stops the run when anything the manifest asked for could not be answered.
///
/// They are reported together rather than one at a time, because a manifest that
/// names three things the checkout does not carry is three lines to fix, and a
/// command that stops at the first turns one pass into three.
///
/// Nothing is written when this throws. A map missing what the package declared
/// would type check against whatever the last run left behind, and the run after
/// it would report a different set.
///
/// Throws a [ToolExit] when [problems] is not empty.

void _refuseUnresolved(List<Unresolved> problems, Manifest manifest, String directory) {
  if (problems.isEmpty) return;

  final StringBuffer said = StringBuffer(
    '${manifest.name} declares ${problems.length == 1 ? 'something' : '${problems.length} things'} '
    'that cannot be resolved, so nothing was written.\n',
  );
  for (final Unresolved problem in problems) {
    said.writeln('  $problem');
  }
  said.write('They are declared in ${p.join(directory, kManifestFile)}.');

  throwToolExit('$said');
}

/// Resolves the package in [directory] against [sdk], and answers what it left.
///
/// What the package reaches is what its manifest declares and nothing besides: the
/// language, the packages it depends on and theirs in turn, and the specifiers the
/// checkout pins that it asked for by name. A package that imports what it never
/// declared does not resolve, which is the point of reading the manifest at all.
///
/// The versions of everything outside the framework are the checkout's, so two
/// packages cannot disagree on which redis client they got, and a package written
/// outside a checkout reaches exactly what it would reach inside one.
///
/// The manifest is read for three reasons: it refuses a directory that is not a
/// package before anything is written, it gives the name the package reaches its
/// own files under, so that a file may cite a neighbour the way everything else
/// does rather than by counting directories, and it names the framework versions
/// the package accepts.
///
/// That last one is checked here and nowhere else, because this is the one place a
/// package and a checkout meet. A checkout the package refuses would otherwise
/// resolve, and the run would end in a hundred type errors that name files rather
/// than the version that caused them.
///
/// Throws a [ToolExit] when [directory] carries no manifest, when it carries one
/// that cannot be read, when the package fails its own checks, when [sdk] is not a
/// checkout the package accepts, and when anything it declared cannot be answered.
Resolution resolve(String directory, Sdk sdk) {
  final Manifest manifest = loadManifest(directory);
  _refuseBroken(manifest, directory);
  _refuseMismatch(manifest, sdk, directory);

  final List<Unresolved> problems = <Unresolved>[];
  final Map<String, String> pinned = sdkImports(sdk);
  final Map<String, String> external = <String, String>{};
  final Map<String, String> reached = packageClosure(manifest, directory, sdk, external, problems);

  final Map<String, String> imports = <String, String>{
    ...kAlwaysResolved,
    ...languageImports(sdk),
    ...externalImports(external, sdk, pinned, problems),
    for (final MapEntry<String, String> held in reached.entries) ..._doorsOf(held.key, held.value),
    ..._doorsOf(manifest.name, directory),
    '@scribe/${manifest.name}/': Uri.directory(p.absolute(directory)).toString(),
  };

  _refuseUnresolved(problems, manifest, directory);

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
/// They are read out of the checkout's own map rather than a manifest of the
/// language's own, because the language is a plain directory of the tree and
/// carries none. The checkout is the one place that says what it publishes, which
/// is also where every other version is pinned.
///
/// Writing one entry and leaving the rest out is what made six of its seven
/// unreachable, so a package that imported one of them failed to resolve while the
/// command line reported nothing.
///
/// Throws a [ToolExit] when the checkout's map names no entry for the language.
Map<String, String> languageImports(Sdk sdk) {
  final Map<String, String> held = sdkImports(sdk);
  final Map<String, String> imports = <String, String>{
    for (final MapEntry<String, String> entry in held.entries)
      if (entry.key == kLanguage || entry.key.startsWith('$kLanguage/')) entry.key: entry.value,
  };

  if (imports.isEmpty) {
    throwToolExit(
      'The map at ${p.join(sdk.root, kSdkImportMapFile)} names no "$kLanguage", so the language cannot be resolved.\n'
      'A checkout publishes the language through its own import map, one entry per surface a package may import.',
    );
  }

  return imports;
}
