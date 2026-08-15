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

final RegExp _topLevelKey = RegExp(r'^([A-Za-z_][A-Za-z0-9_.-]*):');

class YamlFragment {
  const YamlFragment(this.label, this.source);

  final String label;
  final String source;
}

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

  final String? key;
  final List<String> header;
  final List<String> body;

  String render() => <String>[...header, ...body].join('\n');
}
