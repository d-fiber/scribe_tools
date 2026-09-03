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

import 'package:scribe_tools/src/commands/gen/code/sql/sql_type_mapper.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    composites.clear();
    enumNames.clear();
  });

  test('a composite type maps to the fields loadComposites read', () {
    composites['address'] = '{ line1: string }';

    final MappedType mapped = mapPublicType('address');

    expect(mapped.ts, '{ line1: string }');
    expect(mapped.enumName, isNull);
  });

  test('an enum name maps to its Pascal case, naming the enum it came from', () {
    enumNames.add('account_status');

    final MappedType mapped = mapPublicType('account_status');

    expect(mapped.ts, 'AccountStatus');
    expect(mapped.enumName, 'AccountStatus');
  });

  test('a public type that is neither a composite nor a scanned enum maps to unknown', () {
    final MappedType mapped = mapPublicType('email');

    expect(mapped.ts, 'unknown');
    expect(mapped.enumName, isNull, reason: 'a domain is not an enum, so nothing should import it as one');
  });

  test('an array of an enum keeps the enum name, with [] added to the type', () {
    enumNames.add('account_status');

    final MappedType mapped = mapSqlType('public.account_status[]');

    expect(mapped.ts, 'AccountStatus[]');
    expect(mapped.enumName, 'AccountStatus');
  });
}
