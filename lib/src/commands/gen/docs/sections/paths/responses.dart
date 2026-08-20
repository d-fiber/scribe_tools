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
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';

/// The sentence shown beside a status, for the ones the API actually returns.
const Map<int, String> _statusDescriptions = <int, String>{
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  400: 'Validation error',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not found',
  409: 'Conflict',
  413: 'Payload too large',
  422: 'Unprocessable',
  429: 'Too many requests',
  500: 'Unexpected error',
};

/// Writes the `responses` of one operation into [out], at [depth].
///
/// A success and a failure are not described the same way. A success carries
/// its own shape, of which only the code is documented; a failure points at the
/// shared `Error` schema, and the variants become examples so a reader sees the
/// codes an endpoint can really answer with.
void renderResponses(Indented out, int depth, List<GeneratedResponse> responses) {
  out.add(depth, 'responses:');

  for (final GeneratedResponse response in responses) {
    out
      ..add(depth + 1, '"${response.status}":')
      ..add(depth + 2, 'description: ${_statusDescriptions[response.status] ?? 'Response'}')
      ..add(depth + 2, 'content:')
      ..add(depth + 3, 'application/json:')
      ..add(depth + 4, 'schema:');

    if (response.status >= 200 && response.status < 300) {
      _renderSuccessSchema(out, depth + 5, response);
      continue;
    }

    out.add(depth + 5, r'$ref: "#/components/schemas/Error"');
    _renderErrorExamples(out, depth + 4, response);
  }
}

void _renderSuccessSchema(Indented out, int depth, GeneratedResponse response) {
  out
    ..add(depth, 'type: object')
    ..add(depth, 'properties:')
    ..add(depth + 1, 'code:')
    ..add(depth + 2, 'type: string');

  if (response.variants.isEmpty) return;
  if (response.variants.first.code case final String code) {
    out.add(depth + 2, 'example: ${yamlScalar(code)}');
  }
}

/// Writes the examples of a failing status, singular or plural.
///
/// One variant is written as `example`, which readers see expanded; several go
/// under `examples`, each needing a key. A code that repeats gets a numbered
/// suffix, since two examples sharing a key would silently drop one.
void _renderErrorExamples(Indented out, int depth, GeneratedResponse response) {
  if (response.variants.length > 1) {
    out.add(depth, 'examples:');
    final Map<String, int> seen = <String, int>{};

    for (final ResponseVariant variant in response.variants) {
      final String base = variant.code ?? 'variant';
      final int occurrence = (seen[base] ?? 0) + 1;
      seen[base] = occurrence;

      out
        ..add(depth + 1, '${occurrence == 1 ? base : '${base}_$occurrence'}:')
        ..add(depth + 2, 'value:');
      _renderVariantFields(out, depth + 3, variant);
    }
    return;
  }

  if (response.variants.isEmpty) return;

  out.add(depth, 'example:');
  _renderVariantFields(out, depth + 1, response.variants.first);
}

void _renderVariantFields(Indented out, int depth, ResponseVariant variant) {
  if (variant.code case final String code) out.add(depth, 'code: ${yamlScalar(code)}');
  if (variant.message case final String message) out.add(depth, 'message: ${yamlScalar(message)}');
}
