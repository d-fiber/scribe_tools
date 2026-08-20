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

/// One of the shapes a status can come back as, read from the walker's output.
///
/// A single status usually answers with several: a 400 that names a missing
/// field and a 400 that names an unparseable one are two variants of the same
/// status, and OpenAPI shows them as examples under one response.
class ResponseVariant {
  /// Holds [code] and [message] as the walker read them off the route.
  ResponseVariant({required this.code, required this.message});

  /// The machine-readable code this variant answers with, null when it names none.
  final String? code;

  /// The sentence this variant answers with, null when it carries no message.
  final String? message;

  /// Reads a variant from the JSON object the walker prints.
  factory ResponseVariant.fromJson(Map<String, dynamic> json) =>
      ResponseVariant(code: json['code'] as String?, message: json['message'] as String?);
}

/// Every shape one HTTP status of a route can come back as.
class GeneratedResponse {
  /// Holds the [status] and the [variants] the walker found under it.
  GeneratedResponse({required this.status, required this.variants});

  /// The HTTP status this response is the shape of.
  final int status;

  /// The shapes this status comes back as, in the order the walker read them.
  final List<ResponseVariant> variants;

  /// Reads a response from the JSON object the walker prints.
  factory GeneratedResponse.fromJson(Map<String, dynamic> json) => GeneratedResponse(
    status: json['status'] as int,
    variants: (json['variants'] as List<dynamic>)
        .map((dynamic v) => ResponseVariant.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

/// One field of the body a route accepts, nested fields included.
///
/// The shape is recursive because a body is: an array declares what it holds in
/// [items], an object declares what it holds in [properties], and either can go
/// down another level.
class RequestBodyField {
  /// Holds one field of a request body, with whatever it nests.
  RequestBodyField({required this.name, required this.type, required this.required, this.items, this.properties});

  /// The key this field goes by in the JSON body.
  final String name;

  /// The JSON type this field carries, as the walker names it: `string`, `object`, `array`.
  final String type;

  /// Whether the route refuses a body that leaves this field out.
  final bool required;

  /// What an array holds, null for anything that is not an array.
  final RequestBodyField? items;

  /// What an object holds, null for anything that is not an object.
  final List<RequestBodyField>? properties;

  /// Reads a field, and everything it nests, from the JSON the walker prints.
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

/// One route of a surface, with everything the OpenAPI document needs about it.
class GeneratedPathEntry {
  /// Holds one route as the walker read it.
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

  /// The route this entry describes, as the router declares it, with `:name` for its parameters.
  final String path;

  /// The HTTP method, lowercase, the way OpenAPI keys an operation.
  final String method;

  /// The section of the document this route is filed under.
  final String tag;

  /// The one-line description shown next to the operation.
  final String summary;

  /// Whether the route refuses a caller who carries no bearer token.
  final bool requiresAuth;

  /// The permission the caller has to hold, null when the route asks for none.
  final String? requiredPermission;

  /// The fields of the body, null for a route that takes no body.
  final List<RequestBodyField>? requestBody;

  /// Every status the route answers with, and the shapes each comes back as.
  final List<GeneratedResponse> responses;

  /// Reads a route, and everything under it, from the JSON the walker prints.
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

/// Everything one run of the walker found, which is one surface's routes.
class GeneratedPathsDocument {
  /// Holds the routes [paths] the walker read off [surface].
  GeneratedPathsDocument({required this.surface, required this.paths});

  /// The surface that was walked, by the key its directory goes by.
  final String surface;

  /// The routes of that surface, in the order the walker read them.
  final List<GeneratedPathEntry> paths;

  /// Reads a whole walker run from the JSON it prints.
  factory GeneratedPathsDocument.fromJson(Map<String, dynamic> json) => GeneratedPathsDocument(
    surface: json['surface'] as String,
    paths: (json['paths'] as List<dynamic>)
        .map((dynamic e) => GeneratedPathEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
