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

import 'package:scribe_tools/src/commands/gen/docs/docs_surface.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/paths.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/servers.dart';
import 'package:scribe_tools/src/commands/gen/docs/sections/tags.dart';
import 'package:scribe_tools/src/commands/gen/docs/walker/generated_path.dart';

/// The schemas every surface shares, whatever it documents.
///
/// `Error` is the shape a failing response points at, so a code and a message
/// are described once instead of at every status of every route.
const String _components = '''
components:
  schemas:
    Error:
      type: object
      required: [code]
      properties:
        code:
          type: string
        message:
          type: string
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT''';

/// One OpenAPI document, from its five sections.
///
/// The sections are joined by a blank line, which is what makes the generated
/// YAML readable when someone opens it instead of rendering it.
String renderOpenApiDocument({
  required DocsSurface surface,
  required String serverUrl,
  required List<String> tags,
  required List<GeneratedPathEntry> pathEntries,
}) => <String>[
  _renderInfo(surface),
  renderServersSection(serverUrl),
  renderTagsSection(tags),
  _components,
  renderPathsSection(pathEntries),
].join('\n\n');

/// The `info` block, which is what the portal shows above everything else.
///
/// `${APP_NAME}` is left as it stands: the portal substitutes it when it
/// renders, so one document serves whatever the project ends up being called.
String _renderInfo(DocsSurface surface) =>
    '''
openapi: 3.1.0

info:
  title: "${surface.title}"
  version: 1.0.0
  description: "${surface.description}"
  x-logo:
    url: /logo-dark.png
    altText: "\${APP_NAME}"
    backgroundColor: "#09090b"''';
