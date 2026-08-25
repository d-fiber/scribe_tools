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

import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/templates.dart';

/// The templates a new package is written from.
///
/// One flat layer, where a project has `common/` and a layer per SDK. A package
/// is written in TypeScript whatever the checkout carries, so there is nothing
/// for a second layer to hold; the day that stops being true, this grows the
/// same shape as `ProjectTemplates`.
class PackageTemplates {
  /// Reads the templates of [directory], which is a `templates/package/`.
  const PackageTemplates({required this.directory});

  /// The `templates/package/` directory these were read from.
  final Directory directory;

  /// The package templates this tool ships, or null when they are not next to it.
  static PackageTemplates? find() {
    final Directory templates = globals.templatePaths.directoryInPackage(kPackageTemplatesDirectoryName, globals.fs);
    if (!templates.existsSync()) return null;

    return PackageTemplates(directory: templates);
  }

  /// The absolute path of this directory.
  String get path => directory.path;

  /// Every file a new package is written from, sorted by destination.
  List<TemplateFile> get files => readTemplates(directory);
}
