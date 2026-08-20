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

  out.add(depth, 'requestBody:');
  out.add(depth + 1, 'content:');
  out.add(depth + 2, 'application/json:');
  out.add(depth + 3, 'schema:');
  out.add(depth + 4, 'type: object');

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
      out.add(depth + 1, 'type: string');
      out.add(depth + 1, 'format: binary');

    default:
      out.add(depth + 1, 'type: ${openApiType(field.type)}');
  }
}
