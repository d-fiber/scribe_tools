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
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';

/// Writes the `requestBody` of one operation into [out], at [depth].
///
/// The body is always described as a JSON object. A field named as required by
/// the route lands in `required`, and every field is described under
/// `properties`, however deeply it nests.
void renderRequestBody(Indented out, int depth, List<RequestBodyField> fields) {
  final List<String> required = <String>[
    for (final RequestBodyField field in fields)
      if (field.required) field.name,
  ];

  out
    ..add(depth, 'requestBody:')
    ..add(depth + 1, 'content:')
    ..add(depth + 2, 'application/json:')
    ..add(depth + 3, 'schema:')
    ..add(depth + 4, 'type: object');

  if (required.isNotEmpty) out.add(depth + 4, 'required: [${required.join(', ')}]');
  if (fields.isEmpty) return;

  out.add(depth + 4, 'properties:');
  for (final RequestBodyField field in fields) {
    _renderField(out, depth + 5, field);
  }
}

/// Writes one field of a request body, and everything under it.
///
/// A nested object and an array of nested objects both recurse; every other
/// type is one line. An array of scalars stops at its `items` type rather than
/// recursing into a field it does not have.
///
/// The two nested cases do not guard the same way, and this keeps them apart on
/// purpose: an object with an empty field list writes no `properties`, while an
/// array whose items have one writes the key with nothing under it.
void _renderField(Indented out, int depth, RequestBodyField field) {
  out.add(depth, '${field.name}:');

  switch (field.type) {
    case 'nested':
      {
        out.add(depth + 1, 'type: object');
        final List<RequestBodyField>? properties = field.properties;
        if (properties == null || properties.isEmpty) return;

        out.add(depth + 1, 'properties:');
        for (final RequestBodyField property in properties) {
          _renderField(out, depth + 2, property);
        }
      }

    case 'array':
      {
        out.add(depth + 1, 'type: array');
        final RequestBodyField? items = field.items;
        if (items == null) return;

        out.add(depth + 1, 'items:');
        if (items.type != 'nested') {
          out.add(depth + 2, 'type: ${openApiType(items.type)}');
          return;
        }

        out.add(depth + 2, 'type: object');
        final List<RequestBodyField>? properties = items.properties;
        if (properties == null) return;

        out.add(depth + 2, 'properties:');
        for (final RequestBodyField property in properties) {
          _renderField(out, depth + 3, property);
        }
      }

    case 'file':
      out
        ..add(depth + 1, 'type: string')
        ..add(depth + 1, 'format: binary');

    default:
      out.add(depth + 1, 'type: ${openApiType(field.type)}');
  }
}
