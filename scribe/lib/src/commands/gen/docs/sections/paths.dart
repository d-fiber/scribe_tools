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
import '../walker/generated_path.dart';

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

String _openApiPath(String path) => path.replaceAllMapped(RegExp(r':(\w+)'), (Match m) => '{${m[1]}}');

List<String> _pathParams(String path) => RegExp(r':(\w+)').allMatches(path).map((Match m) => m[1]!).toList();

String _openApiType(String type) => type == 'file' ? 'string' : type;

void _renderRequestBodyField(Indented out, int depth, RequestBodyField field) {
  out.add(depth, '${field.name}:');
  switch (field.type) {
    case 'nested':
      out.add(depth + 1, 'type: object');
      if (field.properties != null && field.properties!.isNotEmpty) {
        out.add(depth + 1, 'properties:');
        for (final RequestBodyField prop in field.properties!) {
          _renderRequestBodyField(out, depth + 2, prop);
        }
      }
    case 'array':
      out.add(depth + 1, 'type: array');
      if (field.items != null) {
        out.add(depth + 1, 'items:');
        if (field.items!.type == 'nested') {
          out.add(depth + 2, 'type: object');
          if (field.items!.properties != null) {
            out.add(depth + 2, 'properties:');
            for (final RequestBodyField prop in field.items!.properties!) {
              _renderRequestBodyField(out, depth + 3, prop);
            }
          }
        } else {
          out.add(depth + 2, 'type: ${_openApiType(field.items!.type)}');
        }
      }
    case 'file':
      out.add(depth + 1, 'type: string');
      out.add(depth + 1, 'format: binary');
    default:
      out.add(depth + 1, 'type: ${_openApiType(field.type)}');
  }
}

void _renderRequestBody(Indented out, int depth, List<RequestBodyField> fields) {
  final List<String> required = fields
      .where((RequestBodyField f) => f.required)
      .map((RequestBodyField f) => f.name)
      .toList();

  out.add(depth, 'requestBody:');
  out.add(depth + 1, 'content:');
  out.add(depth + 2, 'application/json:');
  out.add(depth + 3, 'schema:');
  out.add(depth + 4, 'type: object');
  if (required.isNotEmpty) {
    out.add(depth + 4, 'required: [${required.join(', ')}]');
  }
  if (fields.isNotEmpty) {
    out.add(depth + 4, 'properties:');
    for (final RequestBodyField field in fields) {
      _renderRequestBodyField(out, depth + 5, field);
    }
  }
}

void _renderResponses(Indented out, int depth, List<GeneratedResponse> responses) {
  out.add(depth, 'responses:');
  for (final GeneratedResponse response in responses) {
    final String description = _statusDescriptions[response.status] ?? 'Response';
    out.add(depth + 1, '"${response.status}":');
    out.add(depth + 2, 'description: $description');

    if (response.status >= 200 && response.status < 300) {
      out.add(depth + 2, 'content:');
      out.add(depth + 3, 'application/json:');
      out.add(depth + 4, 'schema:');
      out.add(depth + 5, 'type: object');
      out.add(depth + 5, 'properties:');
      out.add(depth + 6, 'code:');
      out.add(depth + 7, 'type: string');
      final String? code = response.variants.isNotEmpty ? response.variants.first.code : null;
      if (code != null) out.add(depth + 7, 'example: ${yamlScalar(code)}');
      continue;
    }

    out.add(depth + 2, 'content:');
    out.add(depth + 3, 'application/json:');
    out.add(depth + 4, 'schema:');
    out.add(depth + 5, r'$ref: "#/components/schemas/Error"');

    if (response.variants.length <= 1) {
      final ResponseVariant? variant = response.variants.isNotEmpty ? response.variants.first : null;
      if (variant != null) {
        out.add(depth + 4, 'example:');
        if (variant.code != null) {
          out.add(depth + 5, 'code: ${yamlScalar(variant.code!)}');
        }
        if (variant.message != null) {
          out.add(depth + 5, 'message: ${yamlScalar(variant.message!)}');
        }
      }
    } else {
      out.add(depth + 4, 'examples:');
      final Map<String, int> seenKeys = <String, int>{};
      for (final ResponseVariant variant in response.variants) {
        final String baseKey = variant.code ?? 'variant';
        final int occurrence = (seenKeys[baseKey] ?? 0) + 1;
        seenKeys[baseKey] = occurrence;
        final String key = occurrence == 1 ? baseKey : '${baseKey}_$occurrence';
        out.add(depth + 5, '$key:');
        out.add(depth + 6, 'value:');
        if (variant.code != null) {
          out.add(depth + 7, 'code: ${yamlScalar(variant.code!)}');
        }
        if (variant.message != null) {
          out.add(depth + 7, 'message: ${yamlScalar(variant.message!)}');
        }
      }
    }
  }
}

String renderPathsSection(List<GeneratedPathEntry> entries) {
  final List<GeneratedPathEntry> sorted = List<GeneratedPathEntry>.of(entries)
    ..sort((GeneratedPathEntry a, GeneratedPathEntry b) {
      final int byPath = a.path.compareTo(b.path);
      return byPath != 0 ? byPath : a.method.compareTo(b.method);
    });

  final Indented out = Indented.empty();
  out.lines.add('paths:');

  String? currentPath;
  for (final GeneratedPathEntry entry in sorted) {
    if (entry.path != currentPath) {
      out.add(1, '${_openApiPath(entry.path)}:');
      currentPath = entry.path;
    }

    out.add(2, '${entry.method}:');
    out.add(3, 'tags: [${entry.tag}]');
    out.add(3, 'summary: ${yamlScalar(entry.summary)}');

    final List<String> params = _pathParams(entry.path);
    if (params.isNotEmpty) {
      out.add(3, 'parameters:');
      for (final String param in params) {
        out.add(4, '- name: $param');
        out.add(5, 'in: path');
        out.add(5, 'required: true');
        out.add(5, 'schema:');
        out.add(6, 'type: string');
      }
    }

    if (entry.requiresAuth) {
      out.add(3, 'security:');
      out.add(4, '- bearerAuth: []');
    }

    if (entry.requiredPermission != null) {
      out.add(3, 'x-required-permission: ${entry.requiredPermission}');
    }

    if (entry.requestBody != null && entry.requestBody!.isNotEmpty) {
      _renderRequestBody(out, 3, entry.requestBody!);
    }

    _renderResponses(out, 3, entry.responses);
  }

  return out.render();
}
