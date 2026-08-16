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

const String kTemplatesDirectoryName = 'templates';

const String kSharedTemplateName = 'common';

const String kGitignoreTemplateName = 'gitignore';

class TemplateFile {
  const TemplateFile({required this.destination, required this.source});

  final String destination;
  final File source;

  bool get isEmptyKeeper => p.basename(destination) == '.gitkeep';

  @override
  String toString() => destination;
}

class ProjectTemplates {
  const ProjectTemplates({required this.directory});

  final Directory directory;

  static ProjectTemplates? find(Directory? frameworkRoot) {
    if (frameworkRoot == null) return null;

    final Directory templates = frameworkRoot.childDirectory(kTemplatesDirectoryName);
    if (!templates.existsSync()) return null;

    return ProjectTemplates(directory: templates);
  }

  String get path => directory.path;

  List<String> get sdkNames => directory
      .listSync(followLinks: false)
      .whereType<Directory>()
      .map((Directory entry) => p.basename(entry.path))
      .where((String name) => name != kSharedTemplateName && !name.startsWith('.'))
      .toList()
    ..sort();

  bool has(String sdkName) => directory.childDirectory(sdkName).existsSync();

  List<TemplateFile> filesFor(String sdkName) {
    final Map<String, TemplateFile> merged = <String, TemplateFile>{};

    for (final String layer in <String>[kSharedTemplateName, sdkName]) {
      final Directory source = directory.childDirectory(layer);
      if (!source.existsSync()) continue;

      for (final TemplateFile file in _read(source)) {
        merged[file.destination] = file;
      }
    }

    final List<TemplateFile> files = merged.values.toList()
      ..sort((TemplateFile a, TemplateFile b) => a.destination.compareTo(b.destination));

    return files;
  }

  List<TemplateFile> _read(Directory source) {
    final List<TemplateFile> found = <TemplateFile>[];

    for (final FileSystemEntity entity in source.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final String relative = p.relative(entity.path, from: source.path);
      found.add(TemplateFile(destination: _destinationOf(relative), source: entity));
    }

    return found;
  }

  static String _destinationOf(String relative) {
    final List<String> segments = p.split(relative);
    if (segments.last == kGitignoreTemplateName) {
      segments[segments.length - 1] = '.$kGitignoreTemplateName';
    }

    return p.posix.joinAll(segments);
  }

  String render(TemplateFile file, Map<String, String> values) {
    final String body = file.source.readAsStringSync();
    if (body.isEmpty) return body;

    return globals.templateRenderer.renderString(file.destination, body, values);
  }
}
