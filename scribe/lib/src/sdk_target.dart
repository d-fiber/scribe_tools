// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/globals.dart' as globals;

/// The SDK a project targets when its manifest names none.
const String kDefaultSdkName = 'js';

/// The directory name that marks everything below it as generated.
const String kGeneratedDirectoryName = 'gen';

/// The languages an SDK directory may be written in, and how they are spelled to a human.
///
/// A directory of `scribe/sdk/` whose name is absent here is ignored rather
/// than offered, so a stray directory never becomes a choice in `create`.
const Map<String, String> kKnownSdks = <String, String>{
  'go': 'Go',
  'dart': 'Dart',
  'python': 'Python',
  'js': 'TS',
  'java': 'Java',
  'kotlin': 'Kotlin',
  'swift': 'Swift',
  'rust': 'Rust',
  'php': 'PHP',
};

/// What a user may type in place of a directory's name, and the directory it means.
///
/// `sdk/js/` holds the TypeScript SDK. The directory keeps the name the
/// framework gives it — renaming it would strand every `config.yaml` that
/// already says `sdk: js` — and `ts` is what someone reaches for on the command
/// line. Both are accepted, and only `ts` is ever printed.
const Map<String, String> kSdkAliases = <String, String>{'ts': 'js'};

/// The directory [asked] names, an alias of [kSdkAliases] resolved.
///
/// Trimmed and lowercased first, since it usually comes from a command line or
/// from `config.yaml`.
String sdkDirectoryFor(String asked) {
  final String wanted = asked.trim().toLowerCase();
  return kSdkAliases[wanted] ?? wanted;
}

/// The name to type for the SDK directory [name]: its alias when it has one.
String sdkSpelling(String name) {
  for (final MapEntry<String, String> alias in kSdkAliases.entries) {
    if (alias.value == name) return alias.key;
  }

  return name;
}

/// The names [kKnownSdks] accepts, spelled as a user types them.
List<String> get kKnownSdkNames => <String>[for (final String name in kKnownSdks.keys) sdkSpelling(name)];

const Set<String> _ignoredDirectories = <String>{
  'node_modules',
  '.git',
  '.dart_tool',
  '.deno',
  'build',
  'example',
  'tests',
};

const Set<String> _dataExtensions = <String>{
  '.json',
  '.yaml',
  '.yml',
  '.lock',
  '.md',
  '.txt',
  '.toml',
  '.sum',
  '.png',
  '.svg',
  '.proto',
};

/// One directory of `scribe/sdk/`, and how much of it is really written.
///
/// The two file counts are what separates a target a project can be built on
/// from one that only holds generated stubs. They are counted rather than
/// declared, so a target becomes offerable the day someone writes in it and
/// nothing has to be updated by hand.
class SdkTarget {
  const SdkTarget({
    required this.name,
    required this.sourceExtension,
    required this.sourceFiles,
    required this.generatedFiles,
  });

  /// A target named [name] that was never looked at, so it counts nothing.
  const SdkTarget.assumed(this.name) : sourceExtension = '', sourceFiles = 0, generatedFiles = 0;

  /// The directory's name, which is also the language's name in [kKnownSdks].
  final String name;

  /// The extension most of its sources carry, empty when it holds no source.
  final String sourceExtension;

  /// The number of hand-written source files.
  final int sourceFiles;

  /// The number of source files sitting under a `gen/` directory.
  final int generatedFiles;

  /// Whether this directory holds no source at all, generated or not.
  bool get isEmpty => sourceFiles == 0 && generatedFiles == 0;

  /// Whether [kKnownSdks] names this directory.
  bool get isRecognised => kKnownSdks.containsKey(name);

  /// The language's name as a human writes it, [name] when it is not recognised.
  String get label => kKnownSdks[name] ?? name;

  /// The name to type for this target: its alias when it has one, else [name].
  String get spelling => sdkSpelling(name);

  /// Whether a project can be built on this target.
  ///
  /// One hand-written file is enough: a target that is only stubs has no
  /// transport, no runtime and no server, so a project on it does not run.
  bool get isReady => sourceFiles > 0;

  /// Whether the file names a new project needs can be derived from this target.
  bool get canScaffold => sourceExtension.isNotEmpty;

  /// How far along this target is, in the two words a listing shows.
  String get state => isReady ? 'ready' : 'stubs only';

  /// Why this target should not be picked, or null when nothing stands against it.
  String? get caveat {
    if (!isRecognised) {
      return 'sdk/$name/ is not a language this CLI knows. The names it accepts are '
          '${kKnownSdkNames.join(', ')}, so a stray directory never becomes a choice.';
    }
    if (isReady) return null;
    if (isEmpty) return 'sdk/$name/ is an empty directory: there is nothing to write against yet.';

    return 'everything under sdk/$name/ is generated — $generatedFiles stub files and no '
        'hand-written line. There is no transport, no runtime and no server, so a project on '
        'this target does not run yet.';
  }

  /// The name of the file the host loads a project through on this target.
  String get entrypointName => 'main$sourceExtension';

  /// The name of the file a directory's middleware goes in on this target.
  String get middlewareName => '_middleware$sourceExtension';

  @override
  String toString() => name;
}

/// Everything found under `scribe/sdk/`, read from the framework next to the caller.
class SdkCatalog {
  const SdkCatalog({required this.root, required this.targets});

  /// The catalog of a machine where no framework was found.
  static const SdkCatalog unknown = SdkCatalog(root: null, targets: <SdkTarget>[]);

  /// The `sdk/` directory this was read from, null when there was none.
  final Directory? root;

  /// Every directory found, recognised or not, sorted by name.
  final List<SdkTarget> targets;

  /// Whether a framework was found at all.
  bool get isKnown => root != null;

  /// The targets worth showing a user: recognised, and holding something.
  List<SdkTarget> get offerable => targets.where((SdkTarget target) => target.isRecognised && !target.isEmpty).toList();

  /// The targets left out of [offerable], which `doctor` says a word about.
  List<SdkTarget> get ignored => targets.where((SdkTarget target) => !target.isRecognised || target.isEmpty).toList();

  /// The target called [name], or null when there is none.
  ///
  /// [name] is trimmed and lowercased first, since it usually comes from
  /// `config.yaml` or from a command line.
  SdkTarget? byName(String name) {
    final String wanted = sdkDirectoryFor(name);

    for (final SdkTarget target in targets) {
      if (target.name == wanted) return target;
    }
    return null;
  }

  /// The names to type for the [offerable] targets.
  List<String> get names => <String>[for (final SdkTarget target in offerable) target.spelling];

  /// The catalog of the framework at or above [from], the current directory by default.
  ///
  /// Returns [unknown] when no framework is found, or when it holds no `sdk/`.
  static SdkCatalog discover({Directory? from}) {
    final Directory? framework = findFrameworkRoot(from ?? globals.fs.currentDirectory);
    if (framework == null) return unknown;

    final Directory sdks = framework.childDirectory('sdk');
    if (!sdks.existsSync()) return unknown;

    final List<SdkTarget> found =
        sdks
            .listSync(followLinks: false)
            .whereType<Directory>()
            .where((Directory entry) => !p.basename(entry.path).startsWith('.'))
            .map(_read)
            .toList()
          ..sort((SdkTarget a, SdkTarget b) => a.name.compareTo(b.name));

    return SdkCatalog(root: sdks, targets: found);
  }

  /// The framework at or above [start], or null when there is none.
  ///
  /// Each directory is tried twice: as the framework itself, and as a project
  /// holding it under `scribe/`. That second try is what lets this run from
  /// inside a project as well as from inside the framework's own checkout.
  static Directory? findFrameworkRoot(Directory start) {
    Directory candidate = start.absolute;

    while (true) {
      if (isFrameworkRoot(candidate)) return candidate;

      final Directory vendored = candidate.childDirectory('scribe');
      if (isFrameworkRoot(vendored)) return vendored;

      final Directory parent = candidate.parent;
      if (parent.path == candidate.path) return null;
      candidate = parent;
    }
  }

  /// Whether [directory] holds the three directories a framework checkout has.
  static bool isFrameworkRoot(Directory directory) =>
      directory.childDirectory('sdk').existsSync() &&
      directory.childDirectory('host').existsSync() &&
      directory.childDirectory('protocol').existsSync();

  static SdkTarget _read(Directory directory) {
    final Map<String, int> sourceExtensions = <String, int>{};
    final Map<String, int> anyExtensions = <String, int>{};
    int sourceFiles = 0;
    int generatedFiles = 0;

    void walk(Directory current, {required bool generated}) {
      for (final FileSystemEntity entity in current.listSync(followLinks: false)) {
        final String basename = p.basename(entity.path);

        if (entity is Directory) {
          if (_ignoredDirectories.contains(basename) || basename.startsWith('.')) continue;
          walk(entity, generated: generated || basename == kGeneratedDirectoryName);
          continue;
        }
        if (entity is! File) continue;

        final String extension = p.extension(basename);
        if (extension.isEmpty || _dataExtensions.contains(extension)) continue;

        anyExtensions[extension] = (anyExtensions[extension] ?? 0) + 1;

        if (generated) {
          generatedFiles++;
          continue;
        }
        sourceFiles++;
        sourceExtensions[extension] = (sourceExtensions[extension] ?? 0) + 1;
      }
    }

    walk(directory, generated: false);

    return SdkTarget(
      name: p.basename(directory.path),
      sourceExtension: _dominant(sourceExtensions.isNotEmpty ? sourceExtensions : anyExtensions),
      sourceFiles: sourceFiles,
      generatedFiles: generatedFiles,
    );
  }

  static String _dominant(Map<String, int> tally) {
    String winner = '';
    int best = 0;

    final List<String> extensions = tally.keys.toList()..sort();
    for (final String extension in extensions) {
      final int count = tally[extension]!;
      if (count > best) {
        best = count;
        winner = extension;
      }
    }

    return winner;
  }
}
