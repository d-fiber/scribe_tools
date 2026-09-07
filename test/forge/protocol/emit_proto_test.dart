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

import 'package:scribe_tools/src/forge/protocol/declared_proto_contract.dart';
import 'package:scribe_tools/src/forge/protocol/emit_proto.dart';
import 'package:test/test.dart';

const String _header = '// This file is auto-generated do not edit manually.\n// Run: scribe forge\n\n';

const DeclaredProtoContract _empty = DeclaredProtoContract(
  name: 'Empty',
  module: null,
  imports: <String>[],
  messages: <DeclaredProtoMessage>[],
  enums: <DeclaredProtoEnumValue>[],
  services: <DeclaredProtoService>[],
);

void main() {
  test('an empty contract renders the header, the syntax line and a package line, nothing else', () {
    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: _empty);

    expect(emitted.text, '${_header}syntax = "proto3";\n\npackage foundation.empty;\n');
  });

  test('the header names the tool and the command that rewrites the file', () {
    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: _empty);

    expect(emitted.text, startsWith(_header));
  });

  test('the file name is the module in snake_case, with a .proto suffix', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.fileName, 'database.proto');
  });

  test('the file name falls back to the contract name in snake_case when it carries no module', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'SocleProtocol',
      module: null,
      imports: <String>[],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'scribe', contract: contract);

    expect(emitted.fileName, 'socle_protocol.proto');
  });

  test('the package line uses the module when one was given', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('package foundation.database;'));
  });

  test('imports render one import statement per path, in order', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>['scribe/protocol/common.proto', 'scribe/protocol/invocation.proto'],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(
      emitted.text,
      '${_header}syntax = "proto3";\n\n'
      'package foundation.database;\n\n'
      'import "scribe/protocol/common.proto";\n'
      'import "scribe/protocol/invocation.proto";\n',
    );
  });

  test('a message renders each field, camelCase names turned to snake_case', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{
            'sql': DeclaredProtoField(
              type: ProtoFieldType(kind: 'scalar', scalar: 'string'),
              number: 1,
              optional: false,
            ),
            'rowLimit': DeclaredProtoField(
              type: ProtoFieldType(kind: 'scalar', scalar: 'uint32'),
              number: 2,
              optional: false,
            ),
          },
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('message Query {\n  string sql = 1;\n  uint32 row_limit = 2;\n}\n'));
  });

  test('optional() marks a field, absent it stays implicit', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{
            'sql': DeclaredProtoField(
              type: ProtoFieldType(kind: 'scalar', scalar: 'string'),
              number: 1,
              optional: true,
            ),
          },
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('optional string sql = 1;'));
  });

  test('a repeated field wraps the base type', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'QueryResult',
          fields: <String, DeclaredProtoField>{
            'rows': DeclaredProtoField(
              type: ProtoFieldType(
                kind: 'repeated',
                of: ProtoFieldType(kind: 'scalar', scalar: 'bytes'),
              ),
              number: 1,
              optional: false,
            ),
          },
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('repeated bytes rows = 1;'));
  });

  test('a map field renders its key and value type', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{
            'params': DeclaredProtoField(
              type: ProtoFieldType(
                kind: 'map',
                key: 'string',
                value: ProtoFieldType(kind: 'scalar', scalar: 'string'),
              ),
              number: 1,
              optional: false,
            ),
          },
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('map<string, string> params = 1;'));
  });

  test('an enum or message field type names the declaration it references', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{
            'isolation': DeclaredProtoField(
              type: ProtoFieldType(kind: 'enum', name: 'Isolation'),
              number: 1,
              optional: false,
            ),
            'header': DeclaredProtoField(
              type: ProtoFieldType(kind: 'message', name: 'Time'),
              number: 2,
              optional: false,
            ),
          },
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('Isolation isolation = 1;'));
    expect(emitted.text, contains('Time header = 2;'));
  });

  test('a message carries its reserved numbers and names', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{},
          reservedNumbers: <int>[2, 3],
          reservedNames: <String>['old_field'],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(emitted.text, contains('reserved 2, 3;'));
    expect(emitted.text, contains('reserved "old_field";'));
  });

  test('an enum renders each value in order', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[
        DeclaredProtoEnumValue(
          name: 'Isolation',
          values: <DeclaredProtoEnumMember>[
            DeclaredProtoEnumMember(name: 'ISOLATION_UNSPECIFIED', number: 0),
            DeclaredProtoEnumMember(name: 'ISOLATION_READ_COMMITTED', number: 1),
          ],
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      services: <DeclaredProtoService>[],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(
      emitted.text,
      contains(
        'enum Isolation {\n'
        '  ISOLATION_UNSPECIFIED = 0;\n'
        '  ISOLATION_READ_COMMITTED = 1;\n'
        '}\n',
      ),
    );
  });

  test('a service renders one rpc line per procedure, in order', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[],
      enums: <DeclaredProtoEnumValue>[],
      services: <DeclaredProtoService>[
        DeclaredProtoService(
          name: 'Database',
          rpcs: <DeclaredProtoRpc>[
            DeclaredProtoRpc(name: 'Execute', request: 'Query', response: 'QueryResult'),
            DeclaredProtoRpc(name: 'ExecuteBatch', request: 'QueryBatch', response: 'QueryBatchResult'),
          ],
        ),
      ],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    expect(
      emitted.text,
      contains(
        'service Database {\n'
        '  rpc Execute(Query) returns (QueryResult);\n'
        '  rpc ExecuteBatch(QueryBatch) returns (QueryBatchResult);\n'
        '}\n',
      ),
    );
  });

  test('messages, enums and services render in that order, each on its own block', () {
    const DeclaredProtoContract contract = DeclaredProtoContract(
      name: 'DatabaseProtocol',
      module: 'database',
      imports: <String>[],
      messages: <DeclaredProtoMessage>[
        DeclaredProtoMessage(
          name: 'Query',
          fields: <String, DeclaredProtoField>{},
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      enums: <DeclaredProtoEnumValue>[
        DeclaredProtoEnumValue(
          name: 'Isolation',
          values: <DeclaredProtoEnumMember>[DeclaredProtoEnumMember(name: 'ISOLATION_UNSPECIFIED', number: 0)],
          reservedNumbers: <int>[],
          reservedNames: <String>[],
        ),
      ],
      services: <DeclaredProtoService>[DeclaredProtoService(name: 'Database', rpcs: <DeclaredProtoRpc>[])],
    );

    final EmittedProtoFile emitted = emitProtoContract(packageName: 'foundation', contract: contract);

    final int messageIndex = emitted.text.indexOf('message Query');
    final int enumIndex = emitted.text.indexOf('enum Isolation');
    final int serviceIndex = emitted.text.indexOf('service Database');

    expect(messageIndex, lessThan(enumIndex));
    expect(enumIndex, lessThan(serviceIndex));
  });
}
