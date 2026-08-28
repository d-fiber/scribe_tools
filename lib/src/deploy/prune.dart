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

/// Takes out of an assembled document the services that are not there any more.
///
/// A resource a target placed somewhere else brings no container, so the service
/// that used to be it has to leave the document, and so does every `depends_on`
/// naming it: Compose refuses a document whose dependency names a service it
/// does not declare.
///
/// This works on lines rather than on a parsed document, for the same reason the
/// merge does: what it is given still carries `{{placeholders}}` that are not
/// valid YAML values yet.
library;

/// The indentation a service of a compose document sits at.
const int _serviceIndent = 2;

/// The indentation an entry of a `depends_on` block sits at.
const int _dependencyIndent = 6;

/// [document] without any service in [gone], and without any dependency on one.
///
/// A document that loses nothing comes back unchanged, character for character,
/// which is what lets a stack with everything in containers be compared to the
/// one that was rendered before any of this existed.
String withoutServices(String document, Set<String> gone) {
  if (gone.isEmpty) return document;

  final List<String> kept = <String>[];
  final List<String> lines = document.split('\n');

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final String? service = _keyAt(line, _serviceIndent);

    if (service != null && gone.contains(service)) {
      i = _endOfBlock(lines, i, _serviceIndent) - 1;
      continue;
    }

    if (line.trimRight().endsWith('depends_on:') && _indentOf(line) == _dependencyIndent - 2) {
      final int end = _endOfBlock(lines, i, _dependencyIndent - 2);
      final List<String> entries = _dependenciesIn(lines.sublist(i + 1, end), gone);
      if (entries.isNotEmpty)
        kept
          ..add(line)
          ..addAll(entries);
      i = end - 1;
      continue;
    }

    kept.add(line);
  }

  return kept.join('\n');
}

/// The entries of a `depends_on` block, without those naming a service in [gone].
List<String> _dependenciesIn(List<String> lines, Set<String> gone) {
  final List<String> kept = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final String? name = _keyAt(lines[i], _dependencyIndent);
    if (name != null && gone.contains(name)) {
      i = _endOfBlock(lines, i, _dependencyIndent) - 1;
      continue;
    }

    kept.add(lines[i]);
  }

  return kept;
}

/// The line after the block opened at [start], whose key sits at [indent].
///
/// A blank line does not end a block: it is written between two services for
/// readability, and treating it as an end would leave half a block behind.
int _endOfBlock(List<String> lines, int start, int indent) {
  for (int i = start + 1; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    if (_indentOf(lines[i]) <= indent) return i;
  }

  return lines.length;
}

/// The key [line] opens at exactly [indent], null when it opens none.
String? _keyAt(String line, int indent) {
  if (_indentOf(line) != indent || !line.trimRight().endsWith(':')) return null;

  final String key = line.trim();

  return key.substring(0, key.length - 1).replaceAll('"', '');
}

int _indentOf(String line) => line.length - line.trimLeft().length;
