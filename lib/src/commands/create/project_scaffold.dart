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
import 'package:scribe_tools/src/commands/create/project_templates.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/sdk_target.dart';
import 'package:scribe_tools/src/templates.dart';

/// What a scaffold writes when nobody told it the framework's version.
const String kUnknownScribeVersion = '0.0.0';

/// The tree `create` writes, and everything that decides what goes in it.
class ProjectScaffold {
  /// Writes a project called [name] into [root], from [templates], for [target].
  ProjectScaffold({
    required this.root,
    required this.name,
    required this.target,
    required this.templates,
    this.scribeVersion = kUnknownScribeVersion,
  });

  /// The directory the project is written into.
  final Directory root;

  /// The project name, as the user typed it, in lower snake case.
  final String name;

  /// The SDK the project is written against, which picks the template layer.
  final SdkTarget target;

  /// The templates on hand, which is what the framework checkout carries.
  final ProjectTemplates templates;

  static const List<String> _generated = <String>['docs', 'ops', 'sdk'];

  List<TemplateFile> get _files => templates.filesFor(target.name);

  /// The directory generated code goes in, hidden and named after the project.
  String get generatedDirectory => '.$name';

  /// The project name as a host name, where an underscore is not allowed.
  String get hostName => name.replaceAll('_', '-');

  /// The version of the framework this project is written against.
  ///
  /// The caller reads it from the checkout, because a scaffold does not know
  /// where one is and a test stands next to none. It is what the manifest
  /// constrains upgrades with.
  final String scribeVersion;

  /// The values every template of this scaffold is filled in from.
  Map<String, String> get values => <String, String>{'name': name, 'host': hostName, 'scribe': scribeVersion};

  /// Every path this scaffold writes, relative to [root].
  List<String> get files => <String>[for (final TemplateFile file in _files) file.destinationFor(values)];

  /// Writes the whole tree, directories first, then every rendered file.
  Future<void> write() async {
    for (final String directory in _generated) {
      await _directory(p.join(root.path, generatedDirectory, directory));
    }

    for (final TemplateFile file in _files) {
      await _write(file.destinationFor(values), file.isEmptyKeeper ? '' : file.render(values));
    }
  }

  Future<void> _directory(String path) => globals.fs.directory(path).create(recursive: true);

  Future<void> _write(String relative, String content) async {
    final File file = globals.fs.file(p.join(root.path, p.joinAll(p.posix.split(relative))));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}
