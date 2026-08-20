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
