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

const String kDefaultSdkName = 'js';

const String kGeneratedDirectoryName = 'gen';

const Map<String, String> kKnownSdks = <String, String>{
  'go': 'Go',
  'dart': 'Dart',
  'python': 'Python',
  'js': 'JavaScript / TypeScript',
  'java': 'Java',
  'kotlin': 'Kotlin',
  'swift': 'Swift',
  'rust': 'Rust',
  'php': 'PHP',
};

List<String> get kKnownSdkNames => kKnownSdks.keys.toList();

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

class SdkTarget {
  const SdkTarget({
    required this.name,
    required this.sourceExtension,
    required this.sourceFiles,
    required this.generatedFiles,
  });

  const SdkTarget.assumed(this.name) : sourceExtension = '', sourceFiles = 0, generatedFiles = 0;

  final String name;
  final String sourceExtension;
  final int sourceFiles;
  final int generatedFiles;

  bool get isEmpty => sourceFiles == 0 && generatedFiles == 0;

  bool get isRecognised => kKnownSdks.containsKey(name);

  String get label => kKnownSdks[name] ?? name;

  bool get isReady => sourceFiles > 0;

  bool get canScaffold => sourceExtension.isNotEmpty;

  String get state => isReady ? 'ready' : 'stubs only';

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

  String get entrypointName => 'main$sourceExtension';

  String get middlewareName => '_middleware$sourceExtension';

  @override
  String toString() => name;
}

class SdkCatalog {
  const SdkCatalog({required this.root, required this.targets});

  static const SdkCatalog unknown = SdkCatalog(root: null, targets: <SdkTarget>[]);

  final Directory? root;
  final List<SdkTarget> targets;

  bool get isKnown => root != null;

  List<SdkTarget> get offerable => targets.where((SdkTarget target) => target.isRecognised && !target.isEmpty).toList();

  List<SdkTarget> get ignored => targets.where((SdkTarget target) => !target.isRecognised || target.isEmpty).toList();

  SdkTarget? byName(String name) {
    final String wanted = name.trim().toLowerCase();

    for (final SdkTarget target in targets) {
      if (target.name == wanted) return target;
    }
    return null;
  }

  List<String> get names => <String>[for (final SdkTarget target in offerable) target.name];

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
