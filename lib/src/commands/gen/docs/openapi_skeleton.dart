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
