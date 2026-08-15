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

class ResponseVariant {
  ResponseVariant({required this.code, required this.message});

  final String? code;
  final String? message;

  factory ResponseVariant.fromJson(Map<String, dynamic> json) =>
      ResponseVariant(code: json['code'] as String?, message: json['message'] as String?);
}

class GeneratedResponse {
  GeneratedResponse({required this.status, required this.variants});

  final int status;
  final List<ResponseVariant> variants;

  factory GeneratedResponse.fromJson(Map<String, dynamic> json) => GeneratedResponse(
    status: json['status'] as int,
    variants: (json['variants'] as List<dynamic>)
        .map((dynamic v) => ResponseVariant.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

class RequestBodyField {
  RequestBodyField({required this.name, required this.type, required this.required, this.items, this.properties});

  final String name;
  final String type;
  final bool required;
  final RequestBodyField? items;
  final List<RequestBodyField>? properties;

  factory RequestBodyField.fromJson(Map<String, dynamic> json) => RequestBodyField(
    name: json['name'] as String,
    type: json['type'] as String,
    required: json['required'] as bool,
    items: json['items'] != null ? RequestBodyField.fromJson(json['items'] as Map<String, dynamic>) : null,
    properties: (json['properties'] as List<dynamic>?)
        ?.map((dynamic f) => RequestBodyField.fromJson(f as Map<String, dynamic>))
        .toList(),
  );
}

class GeneratedPathEntry {
  GeneratedPathEntry({
    required this.path,
    required this.method,
    required this.tag,
    required this.summary,
    required this.requiresAuth,
    required this.requiredPermission,
    required this.requestBody,
    required this.responses,
  });

  final String path;
  final String method;
  final String tag;
  final String summary;
  final bool requiresAuth;
  final String? requiredPermission;
  final List<RequestBodyField>? requestBody;
  final List<GeneratedResponse> responses;

  factory GeneratedPathEntry.fromJson(Map<String, dynamic> json) => GeneratedPathEntry(
    path: json['path'] as String,
    method: json['method'] as String,
    tag: json['tag'] as String,
    summary: json['summary'] as String,
    requiresAuth: json['requiresAuth'] as bool,
    requiredPermission: json['requiredPermission'] as String?,
    requestBody: (json['requestBody'] as List<dynamic>?)
        ?.map((dynamic f) => RequestBodyField.fromJson(f as Map<String, dynamic>))
        .toList(),
    responses: (json['responses'] as List<dynamic>)
        .map((dynamic r) => GeneratedResponse.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

class GeneratedPathsDocument {
  GeneratedPathsDocument({required this.surface, required this.paths});

  final String surface;
  final List<GeneratedPathEntry> paths;

  factory GeneratedPathsDocument.fromJson(Map<String, dynamic> json) => GeneratedPathsDocument(
    surface: json['surface'] as String,
    paths: (json['paths'] as List<dynamic>)
        .map((dynamic e) => GeneratedPathEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
