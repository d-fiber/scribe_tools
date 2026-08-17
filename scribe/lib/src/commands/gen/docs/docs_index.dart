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

import 'dart:convert';

import 'package:change_case/change_case.dart';
import 'package:scribe/src/commands/gen/docs/docs_surface.dart';
import 'package:scribe/src/globals.dart' as globals;

/// Writes the manifest the portal reads before any document.
///
/// It is what turns a directory of YAML files into a navigable site: the portal
/// has no other way to know which surfaces exist or what to call them.
///
/// The placeholders are substituted here and not in the documents, because the
/// portal shows these strings as they are.
Future<void> writeDocsIndex(List<DocsSurface> surfaces) async {
  final String appName = globals.project.manifest.name;

  final Map<String, dynamic> manifest = <String, dynamic>{
    'appName': appName,
    'appNameSnake': appName.toSnakeCase(),
    'basePath': '/developers/docs',
    'surfaces': <Map<String, String>>[
      for (final DocsSurface surface in surfaces)
        <String, String>{
          'key': surface.key,
          'title': _substitute(surface.title, appName),
          'description': _substitute(surface.description, appName),
          'spec': '${surface.key}.yaml',
        },
    ],
  };

  await globals.project.generated.docs.index.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  globals.logger.printStatus('${surfaces.length} surface(s) → ${globals.project.generated.docs.index.path}');
}

String _substitute(String template, String appName) =>
    template.replaceAll(r'${APP_NAME}', appName).replaceAll(r'${APP_NAME_SNAKE}', appName.toSnakeCase());
