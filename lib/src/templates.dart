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

import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// The directory of this package holding everything the tool renders.
const String kTemplatesDirectoryName = 'templates';

/// The layer of [kTemplatesDirectoryName] holding what `create` copies.
///
/// It sits under its own name rather than at the top so that the directories
/// next to it are SDK names and nothing else: `ProjectTemplates.sdkNames` reads
/// that level, and `templates/ops/` would otherwise answer as an SDK called
/// `ops`.
const String kProjectTemplatesDirectoryName = 'project';

/// The layer of [kTemplatesDirectoryName] holding what `pkg create` copies.
const String kPackageTemplatesDirectoryName = 'package';

/// The layer of [kTemplatesDirectoryName] holding what the stack is rendered from.
const String kOpsTemplatesDirectoryName = 'ops';

/// The suffix every file under [kTemplatesDirectoryName] carries, and what it buys.
///
/// It is what keeps a formatter, an analyser or a linter from touching a file
/// full of `{{placeholders}}`. `deno fmt` reads `{{name}}` as a nested flow
/// mapping and writes back `{ { name } }`, which no longer renders; the Dart
/// analyser makes a context root out of a `pubspec.yaml` that names no real
/// package. Under this suffix none of them recognises the file at all.
///
/// A file without it is not a template, and nothing copies it.
const String kTemplateSuffix = '.tmpl';

/// The line that installs the tools, quoted whenever a refusal is about them missing.
const String kInstallCommand =
    'sh -c "\$(curl -fsSL https://raw.githubusercontent.com/d-fiber/scribe_tools/main/install.sh)"';

/// The variable that names the tool's root, and wins over working it out.
///
/// It is there for the two cases the walk cannot answer: a binary reached through
/// a wrapper script, and a checkout whose templates are being tried without
/// reinstalling.
const String kToolRootEnvironmentVariableName = 'SCRIBE_TOOLS_ROOT';

/// The root of the tool, which is the directory [kTemplatesDirectoryName] sits in.
///
/// It is the nearest directory at or above the entrypoint that carries one, and
/// that single rule covers every way the tool is started: an installed binary
/// sits next to its templates, `dart run bin/scribe.dart` sits one level below
/// them, and `dart test` runs a snapshot from a temporary directory that carries
/// nothing at all.
///
/// That last case is why the current directory is tried next. A test is run from
/// the root of the package, so the walk finds the templates that ship. The only
/// other time it is reached is an installation whose templates were never
/// unpacked, and there the answer is the entrypoint's own directory, so that the
/// refusal names where they were expected rather than where they were looked for
/// last.
///
/// [kToolRootEnvironmentVariableName] wins over all of it.
String defaultToolRoot({required Platform platform, required FileSystem fileSystem}) {
  final String? named = platform.environment[kToolRootEnvironmentVariableName];
  if (named != null && named.isNotEmpty) return _absolute(named, fileSystem);

  final String entrypoint = _entrypointDirectory(platform, fileSystem);

  return _carryingTemplates(entrypoint, fileSystem) ??
      _carryingTemplates(fileSystem.currentDirectory.path, fileSystem) ??
      entrypoint;
}

/// The directory the entrypoint of this process sits in.
///
/// A `file:` entrypoint is either the compiled binary or the `.dart` that was
/// run; anything else is a scheme this cannot turn into a path, and the current
/// directory is the only honest answer.
String _entrypointDirectory(Platform platform, FileSystem fileSystem) {
  final Uri script = platform.script;
  if (script.scheme != 'file') return _absolute('.', fileSystem);

  return _absolute(fileSystem.path.dirname(script.toFilePath(windows: platform.isWindows)), fileSystem);
}

/// The nearest directory at or above [start] holding [kTemplatesDirectoryName], or null.
String? _carryingTemplates(String start, FileSystem fileSystem) {
  Directory candidate = fileSystem.directory(_absolute(start, fileSystem));

  while (true) {
    if (candidate.childDirectory(kTemplatesDirectoryName).existsSync()) return candidate.path;

    final Directory parent = candidate.parent;
    if (parent.path == candidate.path) return null;
    candidate = parent;
  }
}

String _absolute(String path, FileSystem fileSystem) => fileSystem.path.normalize(fileSystem.path.absolute(path));

/// Provides the path where the templates the tool renders are stored.
///
/// It is a class rather than a function so that a test can put another one in
/// the context and point every reader at a tree it wrote itself.
class TemplatePathProvider {
  /// Holds nothing: the root is worked out from the entrypoint on every call.
  const TemplatePathProvider();

  /// The root of the tool, the directory [kTemplatesDirectoryName] sits in.
  Directory root(FileSystem fileSystem) =>
      fileSystem.directory(defaultToolRoot(platform: globals.platform, fileSystem: fileSystem));

  /// The directory holding the [name] templates.
  Directory directoryInPackage(String name, FileSystem fileSystem) =>
      root(fileSystem).childDirectory(kTemplatesDirectoryName).childDirectory(name);
}

/// A [TemplatePathProvider] rooted where it is told, rather than at the entrypoint.
///
/// A test writes its templates wherever its file system is convenient, and an
/// installation that keeps them apart from the binary names that directory
/// through [kToolRootEnvironmentVariableName] instead.
class FixedTemplatePathProvider extends TemplatePathProvider {
  /// Answers [directory] whatever the entrypoint says.
  const FixedTemplatePathProvider(this.directory);

  /// The root every path is built from.
  final Directory directory;

  @override
  Directory root(FileSystem fileSystem) => fileSystem.directory(directory.path);
}

/// One file of a template, and where it lands in what is written.
class TemplateFile {
  /// Copies [source] to [destination] of the tree being written.
  const TemplateFile({required this.destination, required this.source});

  /// Where this file goes, relative to the root written into, with POSIX separators.
  ///
  /// It may still carry `{{placeholders}}`, since a file whose name depends on
  /// what is being written spells that in its path. [destinationFor] fills them
  /// in, and until then this is the key two layers are merged on.
  final String destination;

  /// The file it is copied from.
  final File source;

  /// Whether this file is only there to carry an otherwise empty directory.
  bool get isEmptyKeeper => p.basename(destination) == '.gitkeep';

  /// This file read and filled in from [values].
  ///
  /// An empty file comes back empty rather than through the renderer, so a
  /// `.gitkeep` costs nothing.
  ///
  /// Throws a `ToolExit` listing every placeholder [values] has no entry for.
  String render(Map<String, String> values) {
    final String body = source.readAsStringSync();
    if (body.isEmpty) return body;

    return globals.templateRenderer.renderString(destination, body, values);
  }

  /// The path this file lands at, its `{{placeholders}}` filled in from [values].
  ///
  /// A package writes its entry as `lib/{{name}}.ts`, so the name has to reach
  /// the path and not only the contents. A path without a placeholder comes back
  /// unchanged.
  ///
  /// Throws a `ToolExit` listing every placeholder [values] has no entry for.
  String destinationFor(Map<String, String> values) =>
      globals.templateRenderer.renderString(destination, destination, values);

  @override
  String toString() => destination;
}

/// Every [kTemplateSuffix] file under [source], sorted by destination.
///
/// A file without the suffix is passed over rather than refused, which is what
/// keeps a `.DS_Store` from stopping a scaffold. The cost is that a template
/// added without it goes missing from what is written, without a word.
List<TemplateFile> readTemplates(Directory source) {
  final List<TemplateFile> found = <TemplateFile>[];

  for (final FileSystemEntity entity in source.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith(kTemplateSuffix)) continue;

    final String relative = p.relative(entity.path, from: source.path);
    found.add(
      TemplateFile(
        destination: p.posix.joinAll(p.split(relative.substring(0, relative.length - kTemplateSuffix.length))),
        source: entity,
      ),
    );
  }

  return found..sort((TemplateFile a, TemplateFile b) => a.destination.compareTo(b.destination));
}
