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
import 'package:scribe_tools/src/base/common.dart';

/// The engine that fills the holes of a template.
abstract class TemplateRenderer {
  /// Holds nothing, so every renderer can be a constant.
  const TemplateRenderer();

  /// [source] with its placeholders replaced from [values], [name] naming it in errors.
  String renderString(String name, String source, Map<String, String> values);
}

final RegExp _blockPlaceholder = RegExp(r'^([ \t]*)\{\{[ \t]*(\w+)[ \t]*\}\}[ \t]*$', multiLine: true);
final RegExp _inlinePlaceholder = RegExp(r'\{\{[ \t]*(\w+)[ \t]*\}\}');

/// [source] with every `{{key}}` replaced by the [values] entry of that name.
///
/// Spaces inside the braces are allowed and ignored, so `{{key}}` and
/// `{{ key }}` name the same thing. A YAML formatter reads `{{key}}` as a
/// nested flow mapping and writes it back spaced out, and a template that came
/// back from one used to render its own braces into the output instead of
/// failing, since nothing matched them any more.
///
/// A placeholder standing alone on its line inherits that line's indentation,
/// and a value spanning several lines is indented on each of them rather than
/// on the first only. That is what lets a block of generated code be dropped
/// inside an indented template and still line up.
///
/// [name] names the template in the error.
///
/// Throws a [ToolExit] listing every placeholder [values] has no entry for.
/// Nothing is rendered half-way: an unresolved placeholder fails the whole
/// template rather than reaching a file as `{{key}}`.
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
    throwToolExit('$name: ${missing.length} unresolved variable(s): ${(missing.toList()..sort()).join(', ')}');
  }

  return output;
}

String _indentEveryLine(String value, String indent) {
  if (indent.isEmpty) return value;
  return value.split('\n').map((String line) => line.isEmpty ? line : '$indent$line').join('\n');
}
