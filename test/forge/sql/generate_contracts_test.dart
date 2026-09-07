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

import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';
import 'package:scribe_tools/src/forge/sql/generate_contracts.dart';
import 'package:test/test.dart';

const DeclaredSqlMoment _empty = DeclaredSqlMoment(
  tables: <DeclaredSqlTable>[],
  indexes: <DeclaredSqlIndex>[],
  policies: <DeclaredSqlPolicy>[],
  grants: <DeclaredSqlGrant>[],
  sequences: <DeclaredSqlSequence>[],
  enums: <DeclaredSqlEnum>[],
  compositeTypes: <DeclaredSqlCompositeType>[],
  extensions: <DeclaredSqlExtension>[],
  drops: <DeclaredSqlDrop>[],
);

/// A schema whose `init` moment carries whatever is given, everything else empty.
DeclaredSqlSchema _initSchemaOf({
  List<DeclaredSqlEnum> enums = const <DeclaredSqlEnum>[],
  List<DeclaredSqlCompositeType> compositeTypes = const <DeclaredSqlCompositeType>[],
  List<DeclaredSqlTable> tables = const <DeclaredSqlTable>[],
}) => DeclaredSqlSchema(
  init: DeclaredSqlMoment(
    tables: tables,
    indexes: const <DeclaredSqlIndex>[],
    policies: const <DeclaredSqlPolicy>[],
    grants: const <DeclaredSqlGrant>[],
    sequences: const <DeclaredSqlSequence>[],
    enums: enums,
    compositeTypes: compositeTypes,
    extensions: const <DeclaredSqlExtension>[],
    drops: const <DeclaredSqlDrop>[],
  ),
  migrations: _empty,
  provisioning: _empty,
);

void main() {
  test('nothing declared answers null rather than an empty file', () {
    expect(emitContracts(_initSchemaOf()), isNull);
  });

  test('an enum becomes a PascalCase TypeScript enum, its members PascalCase too', () {
    const DeclaredSqlEnum declaredEnum = DeclaredSqlEnum(
      name: 'booking_status',
      values: <String>['pending', 'confirmed'],
    );

    final String contracts = emitContracts(_initSchemaOf(enums: <DeclaredSqlEnum>[declaredEnum]))!;

    expect(contracts, contains('export enum BookingStatus {\n  Pending = "pending",\n  Confirmed = "confirmed",\n}'));
  });

  test('the file opens with a header naming the tool and the command that rewrites it', () {
    const DeclaredSqlEnum declaredEnum = DeclaredSqlEnum(name: 'booking_status', values: <String>['pending']);

    final String contracts = emitContracts(_initSchemaOf(enums: <DeclaredSqlEnum>[declaredEnum]))!;

    expect(contracts, startsWith('// This file is auto-generated do not edit manually.\n// Run: scribe forge\n\n'));
  });

  test('an enum batched under migrations or provisioning still becomes a contract', () {
    const DeclaredSqlEnum declaredEnum = DeclaredSqlEnum(name: 'legacy_status', values: <String>['open']);
    const DeclaredSqlSchema schema = DeclaredSqlSchema(
      init: _empty,
      migrations: DeclaredSqlMoment(
        tables: <DeclaredSqlTable>[],
        indexes: <DeclaredSqlIndex>[],
        policies: <DeclaredSqlPolicy>[],
        grants: <DeclaredSqlGrant>[],
        sequences: <DeclaredSqlSequence>[],
        enums: <DeclaredSqlEnum>[declaredEnum],
        compositeTypes: <DeclaredSqlCompositeType>[],
        extensions: <DeclaredSqlExtension>[],
        drops: <DeclaredSqlDrop>[],
      ),
      provisioning: _empty,
    );

    final String contracts = emitContracts(schema)!;

    expect(contracts, contains('export enum LegacyStatus {'));
  });

  test('a table becomes a PascalCase interface, not singularized, nullable columns unioned with null', () {
    const DeclaredSqlTable table = DeclaredSqlTable(
      name: '__accounts__',
      columns: <String, DeclaredSqlColumn>{
        'id': DeclaredSqlColumn(type: SqlColumnType(kind: 'uuid'), notNull: true, primaryKey: true, unique: false),
        'email': DeclaredSqlColumn(type: SqlColumnType(kind: 'text'), notNull: false, primaryKey: false, unique: false),
      },
      rowLevelSecurity: false,
      revokes: <DeclaredSqlRevoke>[],
    );

    final String contracts = emitContracts(_initSchemaOf(tables: <DeclaredSqlTable>[table]))!;

    expect(contracts, contains('export interface Accounts {'));
    expect(contracts, contains('readonly id: string;'));
    expect(contracts, contains('readonly email: string | null;'));
  });

  test('a column of an enum or a composite type references the generated name, not a widened type', () {
    const DeclaredSqlColumn statusColumn = DeclaredSqlColumn(
      type: SqlColumnType(kind: 'enum', name: 'booking_status'),
      notNull: true,
      primaryKey: false,
      unique: false,
    );
    const DeclaredSqlTable table = DeclaredSqlTable(
      name: '__bookings__',
      columns: <String, DeclaredSqlColumn>{'status': statusColumn},
      rowLevelSecurity: false,
      revokes: <DeclaredSqlRevoke>[],
    );

    final String contracts = emitContracts(
      _initSchemaOf(
        enums: <DeclaredSqlEnum>[
          const DeclaredSqlEnum(name: 'booking_status', values: <String>['pending']),
        ],
        tables: <DeclaredSqlTable>[table],
      ),
    )!;

    expect(contracts, contains('readonly status: BookingStatus;'));
  });
}
