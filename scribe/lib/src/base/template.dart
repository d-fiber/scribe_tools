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
import 'package:scribe/src/base/common.dart';

abstract class TemplateRenderer {
  const TemplateRenderer();

  String renderString(String name, String source, Map<String, String> values);
}

final RegExp _blockPlaceholder = RegExp(r'^([ \t]*)\{\{(\w+)\}\}[ \t]*$', multiLine: true);
final RegExp _inlinePlaceholder = RegExp(r'\{\{(\w+)\}\}');

String renderTemplate(String name, String source, Map<String, String> values) {
  final Set<String> missing = <String>{};

  String resolve(String key, String raw, String indent) {
    final String? value = values[key];
    if (value == null) {
      missing.add(key);
      return raw;
    }
    return _indentEveryLine(value, indent);
  }

  final String blocks = source.replaceAllMapped(
    _blockPlaceholder,
    (Match match) => resolve(match.group(2)!, match.group(0)!, match.group(1)!),
  );

  final String output = blocks.replaceAllMapped(
    _inlinePlaceholder,
    (Match match) => resolve(match.group(1)!, match.group(0)!, ''),
  );

  if (missing.isNotEmpty) {
    throwToolExit('$name: ${missing.length} unresolved variable(s) — ${(missing.toList()..sort()).join(', ')}');
  }

  return output;
}

String _indentEveryLine(String value, String indent) {
  if (indent.isEmpty) return value;
  return value
      .split('\n')
      .map((String line) => line.isEmpty ? line : '$indent$line')
      .join('\n');
}
