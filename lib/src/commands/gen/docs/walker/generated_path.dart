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
