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

/// The two tables every other one is ultimately owned through, and their key.
///
/// They own themselves: a row of `app_users` belongs to the user it is.
const Map<String, String> _rootOwners = <String, String>{
  'internal_t__app_users': 'user_id',
  'internal_t__admin_users': 'admin_id',
};

final RegExp _userOwned = RegExp(
  r'\buser_id\b[^,]*references\s+public\.internal_t__app_users',
  caseSensitive: false,
);

final RegExp _adminOwned = RegExp(
  r'\badmin_id\b[^,]*references\s+public\.internal_t__admin_users',
  caseSensitive: false,
);

/// The column a row of [table] is owned through, or null when nothing owns it.
///
/// Ownership takes the place of row-level security. The query builder injects
/// this column from the identity carried by the request, instead of Postgres
/// filtering on it, so the column has to be known at generation time. That is
/// what `_owners.ts` carries.
///
/// A table is owned as soon as its [body] declares a foreign key to one of the
/// two user tables, which is why this reads the SQL text rather than the parsed
/// columns: the reference and the column name have to be seen together.
String? ownerColumnOf(String table, String body) {
  if (_rootOwners[table] case final String root) return root;
  if (_userOwned.hasMatch(body)) return 'user_id';
  if (_adminOwned.hasMatch(body)) return 'admin_id';

  return null;
}
