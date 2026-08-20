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

final RegExp _topLevelKey = RegExp(r'^([A-Za-z_][A-Za-z0-9_.-]*):');

/// One module's slice of a compose template, and the module it came from.
class YamlFragment {
  const YamlFragment(this.label, this.source);

  /// The module's path, written into the merged document as a comment so a
  /// reader of the generated file can tell which module contributed a block.
  final String label;

  /// The fragment's own YAML, as it sits on disk.
  final String source;
}

/// Merges [fragments] into [base], top-level key by top-level key.
///
/// A fragment's block is appended under the key it shares with [base], and a
/// key no fragment declares is left untouched. A key that exists in no
/// fragment and in no base is appended at the end.
///
/// This works on lines rather than on a parsed document on purpose: the
/// templates carry `{{placeholders}}` that are not valid YAML values yet, so
/// they cannot be parsed before they are rendered.
String mergeYamlDocuments(String base, List<YamlFragment> fragments) {
  final List<_Section> sections = _parse(base);

  for (final YamlFragment fragment in fragments) {
    for (final _Section incoming in _parse(fragment.source)) {
      if (incoming.key == null) continue;

      final int index = sections.indexWhere((_Section section) => section.key == incoming.key);
      if (index < 0) {
        sections.add(_Section(incoming.key, incoming.header, _labelled(fragment.label, incoming.body)));
        continue;
      }

      sections[index].body.addAll(_labelled(fragment.label, incoming.body));
    }
  }

  return '${sections.map((_Section section) => section.render()).join('\n')}\n';
}

List<String> _labelled(String label, List<String> body) {
  final List<String> lines = _trimTrailingBlank(body);
  if (lines.isEmpty) return lines;
  return <String>['${_indentOf(lines.first)}# $label', ...lines];
}

String _indentOf(String line) => line.substring(0, line.length - line.trimLeft().length);

List<String> _trimTrailingBlank(List<String> lines) {
  final List<String> copy = List<String>.of(lines);
  while (copy.isNotEmpty && copy.last.trim().isEmpty) {
    copy.removeLast();
  }
  return copy;
}

List<_Section> _parse(String source) {
  final List<_Section> sections = <_Section>[];
  final List<String> pending = <String>[];

  for (final String line in source.split('\n')) {
    if (!_topLevelKey.hasMatch(line)) {
      if (sections.isEmpty) {
        pending.add(line);
        continue;
      }
      sections.last.body.add(line);
      continue;
    }

    sections.add(_Section(_topLevelKey.firstMatch(line)!.group(1), <String>[...pending, line], <String>[]));
    pending.clear();
  }

  if (pending.isNotEmpty) sections.add(_Section(null, pending, <String>[]));

  for (final _Section section in sections) {
    final List<String> trimmed = _trimTrailingBlank(section.body);
    section.body
      ..clear()
      ..addAll(trimmed);
  }

  return sections;
}

class _Section {
  _Section(this.key, this.header, this.body);

  /// The top-level key this section is under, null for the lines that come
  /// before the first one.
  final String? key;

  final List<String> header;
  final List<String> body;

  String render() => <String>[...header, ...body].join('\n');
}
