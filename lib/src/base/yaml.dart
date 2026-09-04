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
  /// Carries on writing into [lines].
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

/// A scalar written to a YAML document exactly as [text], never quoted.
///
/// For the one case [yamlScalar] cannot serve: a `{{placeholder}}` a deployment substitutes before
/// Compose ever reads the document, where the field it sits in expects a bare number rather than a
/// string once the substitution has run. Quoting it would still be valid YAML, and wrong once
/// substituted: `cpu_shares: "4096"` is a string where Compose's own schema wants a number.
class RawYaml {
  /// Carries [text] to write as-is.
  const RawYaml(this.text);

  /// The text this scalar renders as, verbatim.
  final String text;
}

/// A scalar written on its own line, one level more indented than the key that introduces it,
/// never inline with it.
///
/// [renderTemplate]'s block-placeholder handling needs this shape: a `{{placeholder}}` alone on its
/// own line, preceded only by whitespace, is what tells it to indent every line of the substituted
/// value by that same whitespace. The same placeholder written inline after `key: ` is substituted
/// as plain text instead, with no indenting at all, which corrupts a multi-line substitution such as
/// a gateway plugin's block of allowed origins.
class RawYamlBlock {
  /// Carries [text] to write on its own line, verbatim.
  const RawYamlBlock(this.text);

  /// The text this scalar renders as, verbatim.
  final String text;
}

/// The words YAML's core schema reads as a boolean or a null on their own, case folded.
///
/// A string exactly equal to one of these, unquoted, is not read back as the string it was: it is
/// why `environment: { FORCE_PATH_STYLE: "true" }` has to stay quoted through this function even
/// though `true` alone matches the plain pattern [yamlScalar] otherwise allows unquoted.
const Set<String> _yamlReservedWords = <String>{'true', 'false', 'yes', 'no', 'on', 'off', 'null', '~'};

/// Whether a string reads as a plain YAML number on its own, so quoting it is what keeps it text.
final RegExp _yamlNumberLike = RegExp(r'^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)$');

/// [value] quoted and escaped, unless it is plain enough to stand as it is.
///
/// Plain means letters, digits, underscore, dot, slash and dash, and neither a YAML reserved word
/// nor a number spelled out in full: everything else is double-quoted, since YAML would otherwise
/// read it as structure, or as a value of another type than the string it is.
String yamlScalar(String value) {
  final bool plain = RegExp(r'^[\w./-]+$').hasMatch(value);
  final bool reserved = _yamlReservedWords.contains(value.toLowerCase()) || _yamlNumberLike.hasMatch(value);
  if (plain && !reserved) return value;

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

    if (value is RawYamlBlock) {
      out.add(depth, '$key:');
      out.add(depth + 1, value.text);
      continue;
    }

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
        _renderListItem(out, item, depth + 1);
      }
      continue;
    }

    if (value is String && value.contains('\n')) {
      out.add(depth, '$key: |');
      _writeBlockLiteral(out, value, depth + 1);
      continue;
    }

    out.add(depth, '$key: ${_renderScalar(value)}');
  }
}

/// Writes [item], one entry of a block sequence, with its `- ` marker at [depth].
///
/// A map or a list item is rendered as its own node one level deeper than its marker, its first
/// line then pulled up onto the `- `: that is what keeps `- name: storage` and the keys under it
/// aligned, the ordinary shape of a block sequence of mappings. The marker itself sits one level
/// deeper than the key that introduces the sequence, never flush with it, because that is the
/// convention every hand-written fragment in this repository already uses and [mergeYamlDocuments]
/// appends a fragment's body under the matching key of a base document that was written the same
/// way.
void _renderListItem(Indented out, dynamic item, int depth) {
  if (item is Map || item is List) {
    final Indented nested = Indented.empty();
    if (item is Map) {
      _renderNode(nested, item, depth + 1);
    } else {
      for (final dynamic entry in item as List<dynamic>) {
        _renderListItem(nested, entry, depth + 1);
      }
    }
    if (nested.lines.isEmpty) {
      out.add(depth, '- {}');
      return;
    }
    final String first = nested.lines.first;
    out.lines.add('${'  ' * depth}- ${first.trimLeft()}');
    out.lines.addAll(nested.lines.skip(1));
    return;
  }

  if (item is String && item.contains('\n')) {
    out.add(depth, '- |');
    _writeBlockLiteral(out, item, depth + 1);
    return;
  }

  out.add(depth, '- ${_renderScalar(item)}');
}

/// Writes [text] as the body of a YAML block literal opened by `|`, one line of [out] per line of
/// [text], each indented [depth] levels. A blank line inside [text] is written empty, never padded
/// with trailing spaces a formatter would otherwise strip.
void _writeBlockLiteral(Indented out, String text, int depth) {
  for (final String line in text.split('\n')) {
    if (line.isEmpty) {
      out.lines.add('');
      continue;
    }
    out.add(depth, line);
  }
}

String _renderScalar(dynamic value) {
  if (value == null) return 'null';
  if (value is RawYaml) return value.text;
  if (value is bool || value is num) return '$value';
  return yamlScalar(value.toString());
}
