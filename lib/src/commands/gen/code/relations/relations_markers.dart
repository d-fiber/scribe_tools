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

import 'package:change_case/change_case.dart';
import 'package:file/file.dart';

/// The line that opens the generated relations section of `tables.ts`.
const String relationsMarkerStart = '// @generated:relations:start';

/// The line that closes it.
const String relationsMarkerEnd = '// @generated:relations:end';

/// The relations section of [file], or an empty string when it has none.
///
/// A missing file and a file without markers answer the same way: both mean no
/// relation type is declared yet, and neither is a failure, since the section is
/// written by a later step of the same run.
Future<String> readRelationsSection(File file) async {
  if (!file.existsSync()) return '';

  final String source = await file.readAsString();
  final int start = source.indexOf(relationsMarkerStart);
  final int end = source.indexOf(relationsMarkerEnd);

  return start == -1 || end == -1 ? '' : source.substring(start, end);
}

/// The tables [section] declares a `<X>Relations` type for.
///
/// Read from the section rather than recomputed, because it is the previous
/// run's output that decides what the types are named today.
Set<String> tablesWithRelationsIn(String section, Iterable<String> candidates) => <String>{
  for (final String table in candidates)
    if (section.contains('type ${table.toPascalCase()}Relations =')) table,
};
