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

/// A block of text being built line by line, each line carrying its own indentation.
class Indented {
  Indented(this.lines);

  /// The lines written so far, indentation included.
  final List<String> lines;

  /// Creates a block with nothing in it.
  static Indented empty() => Indented(<String>[]);

  /// Appends [line], indented [depth] levels of two spaces.
  void add(int depth, String line) => lines.add('${'  ' * depth}$line');

  /// The lines joined by newlines, with none at the end.
  String render() => lines.join('\n');
}

/// [value] quoted and escaped, unless it is plain enough to stand as it is.
///
/// Plain means letters, digits, underscore, dot, slash and dash: everything
/// else is double-quoted, since YAML would otherwise read it as structure.
String yamlScalar(String value) {
  if (RegExp(r'^[\w./-]+$').hasMatch(value)) return value;
  final String escaped = value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

/// [doc] serialised as YAML, closed by a newline.
///
/// Only a map produces anything: anything else renders as the newline alone.
///
/// Comments are not preserved, because the parsed document does not carry any.
/// A file written back through this function therefore loses the ones it had.
String renderYaml(dynamic doc) {
  final Indented out = Indented.empty();
  _renderNode(out, doc, 0);
  return '${out.render()}\n';
}

void _renderNode(Indented out, dynamic node, int depth) {
  if (node is! Map) return;

  for (final MapEntry<dynamic, dynamic> entry in node.entries) {
    final String key = entry.key.toString();
    final dynamic value = entry.value;

    if (value is Map) {
      if (value.isEmpty) {
        out.add(depth, '$key: {}');
        continue;
      }
      out.add(depth, '$key:');
      _renderNode(out, value, depth + 1);
      continue;
    }

    if (value is List) {
      if (value.isEmpty) {
        out.add(depth, '$key: []');
        continue;
      }
      out.add(depth, '$key:');
      for (final dynamic item in value) {
        out.add(depth + 1, '- ${_renderScalar(item)}');
      }
      continue;
    }

    out.add(depth, '$key: ${_renderScalar(value)}');
  }
}

String _renderScalar(dynamic value) {
  if (value == null) return '""';
  if (value is bool || value is num) return '$value';
  return yamlScalar(value.toString());
}
