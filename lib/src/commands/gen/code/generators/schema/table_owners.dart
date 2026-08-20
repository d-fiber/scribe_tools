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
