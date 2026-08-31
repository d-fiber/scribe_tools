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
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';

/// The aliases of the framework's own configuration that a project must not inherit.
///
/// They say where the framework sits relative to itself, so they mean something
/// else once the project is somewhere else. Everything besides them, the third
/// party dependencies and their versions, is copied word for word, so that a
/// version is declared in one place only.
const Set<String> _frameworkPathAliases = <String>{
  '@scribe/protocol/',
  '@scribe/public/',
  '@scribe/sdk',
  '@scribe/sdk/',
  '@app/',
  '@assets/',
};

/// The layers a project may name, each one a directory under `engine/`.
///
/// They are aliases and not files because a project reaches into a layer by path,
/// the way the framework's own members do. The checkout keeps each layer's own
/// visibility to itself: those declarations say which layer may reach which, and
/// a project is outside that graph, so it gets all of them.
const List<String> _layers = <String>['contracts', 'runtime', 'kernel', 'embedder', 'testing', 'shell'];

/// The third party imports of [frameworkConfig], its own path aliases removed.
///
/// A path inside the checkout, one whose target starts with `./`, is never one
/// of these: it names a file of the framework, a layer, a package's own or
/// another's, and every one of those is granted on purpose elsewhere, by
/// [mountedDoors] for a package and by the hardcoded block [renderImportMap]
/// writes for a layer. Carrying it here as well would hand back, word for
/// word, every package door [mountedDoors] just refused to grant — the six
/// named [_frameworkPathAliases] are as much a path as any package's, so this
/// used to be the same leak in a second place before the check below closed
/// it: the doors of a package nobody mounted were still reachable through this
/// function, whatever `mountedDoors` decided.
Map<String, String> inheritedImports(Map<String, dynamic> frameworkConfig) {
  final Map<String, dynamic> imports = frameworkConfig['imports'] as Map<String, dynamic>;

  return <String, String>{
    for (final MapEntry<String, dynamic> entry in imports.entries)
      if (!_frameworkPathAliases.contains(entry.key) &&
          entry.value is String &&
          !(entry.value as String).startsWith('./'))
        entry.key: entry.value as String,
  };
}

/// Every specifier the packages a project mounts publish, plus the language.
///
/// It is read rather than listed, in two places. The framework's own map says
/// where the language sits, and each mounted package's map says which doors it
/// opens, so a package that adds one is reached without this tool being told, and
/// a package the framework does not ship is reached the same way as one it does.
///
/// A door of a package is granted only when [mounted] mounts that package.
/// [frameworkConfig] carries the doors of every package the checkout ships,
/// mounted or not, in the one map the whole checkout shares: none of them writes
/// a `deno.json` of its own today. A specifier this checkout answers for a
/// package nobody named is therefore left out of the first pass on purpose, and
/// handed back only in the second, once for each package [mounted] actually
/// carries — the same list `dependencies:` transitively closes for `deploy/`
/// and `scribe.lock` closes for the version check, so a project that reaches a
/// package by name reaches its files the same way it reaches its lifecycle.
///
/// A path inside the checkout comes back relative to it, because the same map is
/// rendered twice, once for this machine and once for the path in the container.
/// A package that lives elsewhere has no such pair and comes back absolute.
Map<String, String> mountedDoors(Directory checkout, Map<String, dynamic> frameworkConfig, Packages mounted) {
  final Map<String, String> doors = <String, String>{};
  final Set<String> known = <String>{for (final Package package in mounted.all) package.name};
  final Object? imports = frameworkConfig['imports'];

  bool namesAPackage(String specifier) =>
      known.any((String name) => specifier == '@scribe/$name' || specifier.startsWith('@scribe/$name/'));

  if (imports is Map<String, dynamic>) {
    for (final MapEntry<String, dynamic> entry in imports.entries) {
      if (namesAPackage(entry.key)) continue;

      final Object? target = entry.value;
      if (target is String && target.startsWith('./')) doors[entry.key] = target.substring(2);
    }
  }

  for (final Package package in mounted.active) {
    if (imports is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in imports.entries) {
        if (entry.key != '@scribe/${package.name}' && !entry.key.startsWith('@scribe/${package.name}/')) continue;

        final Object? target = entry.value;
        if (target is String && target.startsWith('./')) doors[entry.key] = target.substring(2);
      }
    }

    final File map = package.directory.childFile(kSdkImportMapFile);
    if (!map.existsSync()) continue;

    final Object? document = jsonDecode(map.readAsStringSync());
    if (document is! Map<String, dynamic>) continue;

    final Object? own = document['imports'];
    if (own is! Map<String, dynamic>) continue;

    for (final MapEntry<String, dynamic> entry in own.entries) {
      if (entry.key != '@scribe/${package.name}' && !entry.key.startsWith('@scribe/${package.name}/')) continue;

      final Object? target = entry.value;
      if (target is! String || !target.startsWith('./')) continue;

      final String file = p.join(package.directory.path, target.substring(2));
      final String at = p.isWithin(checkout.path, file) ? p.relative(file, from: checkout.path) : file;
      doors[entry.key] = entry.key.endsWith('/') ? asDirectory(at) : at;
    }
  }

  return doors;
}

/// One import map, as the JSON text it is written to disk as.
///
/// [frameworkRoot], [libRoot], [assetsRoot] and every path in [sourceRoots] are
/// what changes between the copy the editor reads and the copy the container is
/// given: the engine's paths do not exist inside the container, so the same map
/// cannot serve both.
///
/// [sourceRoots] is `sources:` turned into aliases, one `@<name>/` per entry,
/// each pointing at a directory next to `lib/` rather than inside it. `@app/`
/// answers for `lib/` alone, the tree a route scan walks, and nothing widens
/// that: a project wanting a name of its own for something that is not a route
/// declares it in `sources:` instead. See `scribe_manifest.dart`.
///
/// `@scribe/sdk/`, which opens the inside of the SDK, is in the map even though
/// a project has no reason to reach through it. The map also compiles the host
/// itself, and the host does. Keeping a project out of there is a convention,
/// not something an import map can enforce.
///
/// [lock] is false for the copy the container reads. Deno writes its lockfile
/// beside the configuration it was given, and the project is mounted read-only
/// there, so a runtime that keeps the lock dies on the first import with a write
/// error naming a file nobody asked for.
String renderImportMap(
  Map<String, dynamic> frameworkConfig,
  Map<String, String> inherited, {
  required String frameworkRoot,
  required String libRoot,
  required String assetsRoot,
  required Map<String, String> sourceRoots,
  required Map<String, String> doors,
  bool lock = true,
}) {
  final String engine = '${frameworkRoot}engine/';

  final Map<String, dynamic> document = <String, dynamic>{
    'imports': <String, String>{
      ...inherited,
      for (final MapEntry<String, String> door in doors.entries)
        door.key: p.isAbsolute(door.value) ? door.value : '$frameworkRoot${door.value}',
      for (final String layer in _layers) '@scribe/$layer/': '$engine$layer/',
      '@scribe/protocol/': '${frameworkRoot}protocol/',
      '@scribe/public/': '${frameworkRoot}public/',
      '@scribe/sdk': '${frameworkRoot}sdk/js/mod.ts',
      '@scribe/sdk/': '${frameworkRoot}sdk/js/',
      '@app/': libRoot,
      for (final MapEntry<String, String> source in sourceRoots.entries) '@${source.key}/': source.value,
      '@assets/': assetsRoot,
      globals.project.generatedAlias: './',
      '@generated/': './',
    },
    if (!lock) 'lock': false,
    if (frameworkConfig['compilerOptions'] != null) 'compilerOptions': frameworkConfig['compilerOptions'],
    if (frameworkConfig['fmt'] != null) 'fmt': frameworkConfig['fmt'],
  };

  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

/// [path] with a trailing separator, which an import map prefix needs.
String asDirectory(String path) => path.endsWith(p.separator) ? path : '$path${p.separator}';
