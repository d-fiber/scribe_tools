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

/// The variable that names the tool's root, and wins over working it out.
///
/// It is there for the two cases the entrypoint cannot answer: a binary reached
/// through a wrapper script, and a checkout whose templates are being tried
/// without reinstalling.
const String kToolRootEnvironmentVariableName = 'SCRIBE_TOOLS_ROOT';

/// The directory of this package holding its entrypoints.
const String _binDirectoryName = 'bin';

/// The root of the tool, which is the directory [kTemplatesDirectoryName] sits in.
///
/// Five cases, tried in this order:
///
///   1. [kToolRootEnvironmentVariableName], when it is set.
///   2. A `data:` entrypoint, which is a test run: the current directory, since
///      a test is run from the root of the package.
///   3. A `package:` entrypoint: the two parents of the `package_config.json`
///      it resolves through, which is `<root>/.dart_tool/package_config.json`.
///   4. A `file:` entrypoint, which is either `<root>/bin/scribe.dart` under
///      `dart run`, or the compiled binary itself. The name of the parent
///      directory is what tells them apart, and an installed binary sits next
///      to the templates rather than one level above them.
///   5. The current directory, when the entrypoint carries a scheme none of the
///      above knows.
String defaultToolRoot({required Platform platform, required FileSystem fileSystem}) {
  String normalize(String path) => fileSystem.path.normalize(fileSystem.path.absolute(path));

  final String? named = platform.environment[kToolRootEnvironmentVariableName];
  if (named != null && named.isNotEmpty) return normalize(named);

  final Uri script = platform.script;

  if (script.scheme == 'package') {
    final String? configuration = platform.packageConfig;
    if (configuration != null) {
      final String path = Uri.parse(configuration).toFilePath(windows: platform.isWindows);
      return normalize(fileSystem.path.dirname(fileSystem.path.dirname(path)));
    }
  }

  if (script.scheme == 'file') {
    final String path = script.toFilePath(windows: platform.isWindows);
    final String parent = fileSystem.path.dirname(path);

    if (fileSystem.path.basename(parent) == _binDirectoryName) {
      return normalize(fileSystem.path.dirname(parent));
    }
    return normalize(parent);
  }

  return normalize('.');
}

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
