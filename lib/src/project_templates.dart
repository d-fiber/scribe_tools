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

import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/templates.dart';

/// The layer every project gets, whatever SDK it targets.
const String kSharedTemplateName = 'common';

/// The templates a new project is scaffolded from.
///
/// They are two layers deep: [kSharedTemplateName] holds what every project
/// gets, and a directory per SDK holds what only that target needs. The SDK
/// layer wins file by file. See [filesFor].
class ProjectTemplates {
  /// Reads the templates of [directory], which is a `templates/project/`.
  const ProjectTemplates({required this.directory});

  /// The `templates/project/` directory these were read from.
  final Directory directory;

  /// The project templates this tool ships, or null when they are not next to it.
  ///
  /// Null means the tool was installed without them, which is the one case a
  /// caller has to explain rather than work around: nothing else on the machine
  /// holds them.
  static ProjectTemplates? find() {
    final Directory templates = globals.templatePaths.directoryInPackage(kProjectTemplatesDirectoryName, globals.fs);
    if (!templates.existsSync()) return null;

    return ProjectTemplates(directory: templates);
  }

  /// The absolute path of this directory.
  String get path => directory.path;

  /// The SDKs a template exists for, sorted, the shared layer left out.
  List<String> get sdkNames =>
      directory
          .listSync(followLinks: false)
          .whereType<Directory>()
          .map((Directory entry) => p.basename(entry.path))
          .where((String name) => name != kSharedTemplateName && !name.startsWith('.'))
          .toList()
        ..sort();

  /// Whether a template exists for [sdkName].
  bool has(String sdkName) => directory.childDirectory(sdkName).existsSync();

  /// Every file a project on [sdkName] is scaffolded from, sorted by destination.
  ///
  /// The shared layer is read first and the SDK layer second, so a file present
  /// in both is taken from the SDK: a target replaces what it needs to and
  /// inherits the rest. A layer that does not exist contributes nothing.
  List<TemplateFile> filesFor(String sdkName) {
    final Map<String, TemplateFile> merged = <String, TemplateFile>{};

    for (final String layer in <String>[kSharedTemplateName, sdkName]) {
      final Directory source = directory.childDirectory(layer);
      if (!source.existsSync()) continue;

      for (final TemplateFile file in readTemplates(source)) {
        merged[file.destination] = file;
      }
    }

    final List<TemplateFile> files = merged.values.toList()
      ..sort((TemplateFile a, TemplateFile b) => a.destination.compareTo(b.destination));

    return files;
  }
}
