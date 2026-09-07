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

/// One `@Proto(...)` class, exactly as the bridge printed it: its own name, the module it was
/// given, the `.proto` files it imports, and what its decorated methods declared, already sorted
/// and checked for a name reused across two declarations — the bridge runs the same
/// `protocol.builder` a hand-written `build()` would, so this never sees a raw, unsorted list.
class DeclaredProtoContract {
  /// Holds a contract exactly as the bridge printed it.
  const DeclaredProtoContract({
    required this.name,
    required this.module,
    required this.imports,
    required this.messages,
    required this.enums,
    required this.services,
  });

  /// The class name this contract was declared under.
  final String name;

  /// The module `@Proto(module)` was given, null for the socle.
  final String? module;

  /// The `.proto` files this contract's own `imports()` named, by path.
  final List<String> imports;

  /// The messages this contract declares, in declaration order.
  final List<DeclaredProtoMessage> messages;

  /// The enums this contract declares, in declaration order.
  final List<DeclaredProtoEnumValue> enums;

  /// The services this contract declares, in declaration order.
  final List<DeclaredProtoService> services;

  /// Reads one contract from the JSON object the bridge prints.
  factory DeclaredProtoContract.fromJson(Map<String, dynamic> json) => DeclaredProtoContract(
    name: json['name'] as String,
    module: json['module'] as String?,
    imports: (json['imports'] as List<dynamic>).cast<String>(),
    messages: (json['messages'] as List<dynamic>)
        .map((dynamic entry) => DeclaredProtoMessage.fromJson(entry as Map<String, dynamic>))
        .toList(),
    enums: (json['enums'] as List<dynamic>)
        .map((dynamic entry) => DeclaredProtoEnumValue.fromJson(entry as Map<String, dynamic>))
        .toList(),
    services: (json['services'] as List<dynamic>)
        .map((dynamic entry) => DeclaredProtoService.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );
}

/// One `message`, exactly as `DeclaredMessage` resolved it on the TypeScript side.
class DeclaredProtoMessage {
  /// Holds a message exactly as the bridge printed it.
  const DeclaredProtoMessage({
    required this.name,
    required this.fields,
    required this.reservedNumbers,
    required this.reservedNames,
  });

  /// The name this message was created under.
  final String name;

  /// This message's fields, by field name, in declaration order.
  final Map<String, DeclaredProtoField> fields;

  /// The field numbers this message retires from a previous version of the contract.
  final List<int> reservedNumbers;

  /// The field names this message retires from a previous version of the contract.
  final List<String> reservedNames;

  /// Reads one message from the JSON object the bridge prints.
  factory DeclaredProtoMessage.fromJson(Map<String, dynamic> json) => DeclaredProtoMessage(
    name: json['name'] as String,
    fields: (json['fields'] as Map<String, dynamic>).map(
      (String field, dynamic value) =>
          MapEntry<String, DeclaredProtoField>(field, DeclaredProtoField.fromJson(value as Map<String, dynamic>)),
    ),
    reservedNumbers: (json['reservedNumbers'] as List<dynamic>).cast<int>(),
    reservedNames: (json['reservedNames'] as List<dynamic>).cast<String>(),
  );
}

/// One field of a [DeclaredProtoMessage].
class DeclaredProtoField {
  /// Holds a field exactly as the bridge printed it.
  const DeclaredProtoField({required this.type, required this.number, required this.optional});

  /// The proto3 type this field holds.
  final ProtoFieldType type;

  /// The field number this field takes on the wire.
  final int number;

  /// Whether this field carries proto3's explicit presence tracking (`optional`).
  final bool optional;

  /// Reads one field from the JSON object the bridge prints.
  factory DeclaredProtoField.fromJson(Map<String, dynamic> json) => DeclaredProtoField(
    type: ProtoFieldType.fromJson(json['type'] as Map<String, dynamic>),
    number: json['number'] as int,
    optional: json['optional'] as bool,
  );
}

/// The proto3 type a field holds, exactly as `FieldType` resolved it on the TypeScript side.
///
/// [scalar] is set only when [kind] is `scalar`. [name] is set only when [kind] is `enum` or
/// `message`, naming another declaration of the same contract. [of] is set only when [kind] is
/// `repeated`, naming what it repeats. [key] and [value] are set only when [kind] is `map`.
class ProtoFieldType {
  /// Holds a type exactly as the bridge printed it.
  const ProtoFieldType({required this.kind, this.scalar, this.name, this.of, this.key, this.value});

  /// Which shape this type takes: `scalar`, `enum`, `message`, `repeated` or `map`.
  final String kind;

  /// The proto3 scalar kind, spelled the way a `.proto` file takes it.
  final String? scalar;

  /// The enum or message name a reference names.
  final String? name;

  /// What a `repeated` field repeats.
  final ProtoFieldType? of;

  /// The key kind of a `map`.
  final String? key;

  /// The value type of a `map`.
  final ProtoFieldType? value;

  /// Reads one type from the JSON object the bridge prints.
  factory ProtoFieldType.fromJson(Map<String, dynamic> json) => ProtoFieldType(
    kind: json['kind'] as String,
    scalar: json['scalar'] as String?,
    name: json['name'] as String?,
    of: json['of'] != null ? ProtoFieldType.fromJson(json['of'] as Map<String, dynamic>) : null,
    key: json['key'] as String?,
    value: json['value'] != null ? ProtoFieldType.fromJson(json['value'] as Map<String, dynamic>) : null,
  );
}

/// One `enum`, exactly as `DeclaredProtoEnum` resolved it on the TypeScript side.
///
/// Named `DeclaredProtoEnumValue` rather than `DeclaredProtoEnum`: this Dart package already has a
/// `DeclaredSqlEnum` for a Postgres enum, and the two would read as the same thing at a glance.
class DeclaredProtoEnumValue {
  /// Holds an enum exactly as the bridge printed it.
  const DeclaredProtoEnumValue({
    required this.name,
    required this.values,
    required this.reservedNumbers,
    required this.reservedNames,
  });

  /// The name this enum was created under.
  final String name;

  /// The values this enum accepts, in declaration order. The first always numbers `0`.
  final List<DeclaredProtoEnumMember> values;

  /// The numbers this enum retires from a previous version of the contract.
  final List<int> reservedNumbers;

  /// The names this enum retires from a previous version of the contract.
  final List<String> reservedNames;

  /// Reads one enum from the JSON object the bridge prints.
  factory DeclaredProtoEnumValue.fromJson(Map<String, dynamic> json) => DeclaredProtoEnumValue(
    name: json['name'] as String,
    values: (json['values'] as List<dynamic>)
        .map((dynamic entry) => DeclaredProtoEnumMember.fromJson(entry as Map<String, dynamic>))
        .toList(),
    reservedNumbers: (json['reservedNumbers'] as List<dynamic>).cast<int>(),
    reservedNames: (json['reservedNames'] as List<dynamic>).cast<String>(),
  );
}

/// One value of a [DeclaredProtoEnumValue].
class DeclaredProtoEnumMember {
  /// Holds a value exactly as the bridge printed it.
  const DeclaredProtoEnumMember({required this.name, required this.number});

  /// The name this value is declared under.
  final String name;

  /// The number this value takes on the wire.
  final int number;

  /// Reads one value from the JSON object the bridge prints.
  factory DeclaredProtoEnumMember.fromJson(Map<String, dynamic> json) =>
      DeclaredProtoEnumMember(name: json['name'] as String, number: json['number'] as int);
}

/// One `service`, exactly as `DeclaredRpcService` resolved it on the TypeScript side.
class DeclaredProtoService {
  /// Holds a service exactly as the bridge printed it.
  const DeclaredProtoService({required this.name, required this.rpcs});

  /// The name this service was created under.
  final String name;

  /// The procedures this service carries, in declaration order.
  final List<DeclaredProtoRpc> rpcs;

  /// Reads one service from the JSON object the bridge prints.
  factory DeclaredProtoService.fromJson(Map<String, dynamic> json) => DeclaredProtoService(
    name: json['name'] as String,
    rpcs: (json['rpcs'] as List<dynamic>)
        .map((dynamic entry) => DeclaredProtoRpc.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );
}

/// One procedure of a [DeclaredProtoService].
class DeclaredProtoRpc {
  /// Holds a procedure exactly as the bridge printed it.
  const DeclaredProtoRpc({required this.name, required this.request, required this.response});

  /// The name this procedure is declared under.
  final String name;

  /// The message this procedure takes, by name.
  final String request;

  /// The message this procedure answers, by name.
  final String response;

  /// Reads one procedure from the JSON object the bridge prints.
  factory DeclaredProtoRpc.fromJson(Map<String, dynamic> json) => DeclaredProtoRpc(
    name: json['name'] as String,
    request: json['request'] as String,
    response: json['response'] as String,
  );
}
