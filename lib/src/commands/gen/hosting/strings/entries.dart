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

import 'template.dart';

class Entry {
  Entry(this.en, this.fr);

  final String en;
  final String fr;
}

Map<String, Entry> parseEntries(String csv, Map<String, String> tokens) {
  final List<String> lines = csv
      .split('\n')
      .map((String l) => l.trim())
      .where((String l) => l.isNotEmpty && !l.startsWith('Comment'))
      .toList();

  final Map<String, Entry> entries = <String, Entry>{};
  for (final String line in lines) {
    final List<String> parts = line.split(';');
    final String? id = parts.length > 1 ? parts[1] : null;
    final String? en = parts.length > 2 ? parts[2] : null;
    final String? fr = parts.length > 3 ? parts[3] : null;
    if (id != null && id.trim().isNotEmpty) {
      entries[id.trim()] = Entry(applyTemplate(en?.trim() ?? '', tokens), applyTemplate(fr?.trim() ?? '', tokens));
    }
  }
  return entries;
}
