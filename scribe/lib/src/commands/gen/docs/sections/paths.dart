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

import 'package:scribe/src/base/yaml.dart';
import 'package:scribe/src/commands/gen/docs/sections/paths/path_syntax.dart';
import 'package:scribe/src/commands/gen/docs/sections/paths/request_body.dart';
import 'package:scribe/src/commands/gen/docs/sections/paths/responses.dart';
import 'package:scribe/src/commands/gen/docs/walker/generated_path.dart';

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

  final Indented out = Indented.empty();
  out.add(0, 'paths:');

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
  out.add(2, '${entry.method}:');
  out.add(3, 'tags: [${entry.tag}]');
  out.add(3, 'summary: ${yamlScalar(entry.summary)}');

  _renderPathParameters(out, entry.path);

  if (entry.requiresAuth) {
    out.add(3, 'security:');
    out.add(4, '- bearerAuth: []');
  }

  if (entry.requiredPermission case final String permission) {
    out.add(3, 'x-required-permission: $permission');
  }

  if (entry.requestBody case final List<RequestBodyField> body when body.isNotEmpty) {
    renderRequestBody(out, 3, body);
  }

  renderResponses(out, 3, entry.responses);
}

/// Declares every `:name` of [path] as a required string parameter.
///
/// They are always required and always strings: a path parameter that could be
/// absent would be a different route, and the router hands them over as text.
void _renderPathParameters(Indented out, String path) {
  final List<String> names = pathParameters(path);
  if (names.isEmpty) return;

  out.add(3, 'parameters:');
  for (final String name in names) {
    out.add(4, '- name: $name');
    out.add(5, 'in: path');
    out.add(5, 'required: true');
    out.add(5, 'schema:');
    out.add(6, 'type: string');
  }
}
