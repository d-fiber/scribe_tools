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

import 'package:change_case/change_case.dart';
import 'package:scribe_tools/src/commands/gen/docs/docs_surface.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// Writes the manifest the portal reads before any document.
///
/// It is what turns a directory of YAML files into a navigable site: the portal
/// has no other way to know which surfaces exist or what to call them.
///
/// The placeholders are substituted here and not in the documents, because the
/// portal shows these strings as they are.
Future<void> writeDocsIndex(List<DocsSurface> surfaces) async {
  final String appName = globals.project.manifest.name;

  final Map<String, dynamic> manifest = <String, dynamic>{
    'appName': appName,
    'appNameSnake': appName.toSnakeCase(),
    'basePath': '/developers/docs',
    'surfaces': <Map<String, String>>[
      for (final DocsSurface surface in surfaces)
        <String, String>{
          'key': surface.key,
          'title': _substitute(surface.title, appName),
          'description': _substitute(surface.description, appName),
          'spec': '${surface.key}.yaml',
        },
    ],
  };

  await globals.project.generated.docs.index.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  globals.logger.printStatus('${surfaces.length} surface(s) → ${globals.project.generated.docs.index.path}');
}

String _substitute(String template, String appName) =>
    template.replaceAll(r'${APP_NAME}', appName).replaceAll(r'${APP_NAME_SNAKE}', appName.toSnakeCase());
