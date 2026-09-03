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

import 'package:scribe_tools/src/base/yaml.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/paths/path_syntax.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/paths/request_body.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/paths/responses.dart';
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';

/// The `paths` section of an OpenAPI document, one block per route.
///
/// Entries are sorted by path and then by method, so a document only changes
/// when a route does. The order the walker found them in would otherwise leak
/// into the diff.
///
/// Routes sharing a path are written under one key: OpenAPI groups the methods
/// of a path together, which is why the path is only emitted when it changes.
String renderPathsSection(List<GeneratedPathEntry> entries) {
  final List<GeneratedPathEntry> sorted = List<GeneratedPathEntry>.of(entries)..sort(_byPathThenMethod);

  final Indented out = Indented.empty()..add(0, 'paths:');

  String? currentPath;
  for (final GeneratedPathEntry entry in sorted) {
    if (entry.path != currentPath) {
      out.add(1, '${openApiPath(entry.path)}:');
      currentPath = entry.path;
    }
    _renderOperation(out, entry);
  }

  return out.render();
}

int _byPathThenMethod(GeneratedPathEntry a, GeneratedPathEntry b) {
  final int byPath = a.path.compareTo(b.path);
  return byPath != 0 ? byPath : a.method.compareTo(b.method);
}

void _renderOperation(Indented out, GeneratedPathEntry entry) {
  out
    ..add(2, '${entry.method}:')
    ..add(3, 'tags: [${entry.tag}]')
    ..add(3, 'summary: ${yamlScalar(entry.summary)}');

  _renderPathParameters(out, entry.path);

  if (entry.requiresAuth) {
    out
      ..add(3, 'security:')
      ..add(4, '- bearerAuth: []');
  }

  if (entry.requiredPermission case final String permission) {
    out.add(3, 'x-required-permission: $permission');
  }

  if (entry.requestBody case final List<RequestBodyField> body when body.isNotEmpty) {
    renderRequestBody(out, 3, body);
  }

  renderResponses(out, 3, entry.responses);
}

/// Declares every distinct `:name` of [path] as a required string parameter.
///
/// They are always required and always strings: a path parameter that could be
/// absent would be a different route, and the router hands them over as text.
///
/// A name is declared once even when the route repeats it, `:id/friends/:id`
/// among the shapes that would otherwise emit it twice: OpenAPI takes one
/// `parameters` entry per name, and a second one for the same name is not a
/// second parameter, only an invalid document.
void _renderPathParameters(Indented out, String path) {
  final List<String> names = pathParameters(path).toSet().toList();
  if (names.isEmpty) return;

  out.add(3, 'parameters:');
  for (final String name in names) {
    out
      ..add(4, '- name: $name')
      ..add(5, 'in: path')
      ..add(5, 'required: true')
      ..add(5, 'schema:')
      ..add(6, 'type: string');
  }
}
