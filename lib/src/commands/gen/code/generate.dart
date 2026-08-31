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
import 'package:scribe_tools/src/commands/gen/code/generators/schema/enums.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/schema/tables.dart';
import 'package:scribe_tools/src/commands/gen/code/relations/relations.dart';

/// Rewrites what a project derives from its SQL: the enums, the row and table
/// types, and the relations between them.
///
/// What a project derives from `dependencies:` instead, the import map, the
/// registrations and the declarations, is `forge`'s now: the same thing that
/// decides which package is mounted is the thing that has to write what mounting
/// it means, in the one step, the way `pub get` resolves and writes
/// `.dart_tool/package_config.json` together rather than across two commands a
/// developer can run out of order. This command is left with what only the SQL
/// decides, which `forge` has no reason to read.
///
/// The order is fixed: the enums before the tables that name them.
Future<void> generateProjectCode() async {
  await generateTables(await generateEnums());
  await generateRelations();
}
