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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/forge/protocol/declared_proto_contract.dart';

/// One `@Proto(...)` class, rendered to the `.proto` text it describes.
class EmittedProtoFile {
  /// Holds the file name a contract renders under, and its own text.
  const EmittedProtoFile({required this.fileName, required this.text});

  /// The file this contract renders to, its own class name in snake_case with a `.proto` suffix.
  final String fileName;

  /// The `.proto` text this contract renders to.
  final String text;
}

/// Renders [contract] to the `.proto` text it describes, qualified under [packageName].
///
/// The proto `package` this writes is provisional: `$packageName.<module or contract name>` names
/// something distinct for every contract a package declares, but it does not yet follow
/// `scribe.v1`/`scribe.runtime.*`/`scribe.clients.*`, the convention `protocol.md` documents for
/// the framework's own thirteen `.proto` — that convention still needs to read a contract's family
/// from where its source file sits on disk, a decision `alchemy/protocol.md`'s own "Ce qui manque
/// encore" leaves open. This emits something `protoc` accepts today, not the final naming.
EmittedProtoFile emitProtoContract({required String packageName, required DeclaredProtoContract contract}) {
  final StringBuffer buffer = StringBuffer()
    ..write(generatedFileHeader('forge'))
    ..writeln()
    ..writeln('syntax = "proto3";')
    ..writeln()
    ..writeln('package $packageName.${contract.module ?? contract.name.toLowerCase()};');

  if (contract.imports.isNotEmpty) {
    buffer.writeln();
    for (final String path in contract.imports) {
      buffer.writeln('import "$path";');
    }
  }

  for (final DeclaredProtoMessage message in contract.messages) {
    buffer
      ..writeln()
      ..write(_message(message));
  }

  for (final DeclaredProtoEnumValue value in contract.enums) {
    buffer
      ..writeln()
      ..write(_enum(value));
  }

  for (final DeclaredProtoService service in contract.services) {
    buffer
      ..writeln()
      ..write(_service(service));
  }

  return EmittedProtoFile(fileName: '${contract.name.toSnakeCase()}.proto', text: buffer.toString());
}

String _message(DeclaredProtoMessage message) {
  final StringBuffer buffer = StringBuffer('message ${message.name} {\n');

  if (message.reservedNumbers.isNotEmpty) {
    buffer.writeln('  reserved ${message.reservedNumbers.join(', ')};');
  }
  if (message.reservedNames.isNotEmpty) {
    buffer.writeln('  reserved ${message.reservedNames.map((String name) => '"$name"').join(', ')};');
  }
  for (final MapEntry<String, DeclaredProtoField> entry in message.fields.entries) {
    buffer.writeln('  ${_field(entry.key, entry.value)}');
  }

  buffer.write('}\n');
  return buffer.toString();
}

String _field(String name, DeclaredProtoField field) {
  final String prefix = field.optional ? 'optional ' : '';
  return '$prefix${_type(field.type)} ${name.toSnakeCase()} = ${field.number};';
}

String _type(ProtoFieldType type) {
  switch (type.kind) {
    case 'scalar':
      return type.scalar!;
    case 'enum':
    case 'message':
      return type.name!;
    case 'repeated':
      return 'repeated ${_type(type.of!)}';
    case 'map':
      return 'map<${type.key}, ${_type(type.value!)}>';
    default:
      throwToolExit('"${type.kind}" is not a proto3 field type this renderer knows.');
  }
}

String _enum(DeclaredProtoEnumValue value) {
  final StringBuffer buffer = StringBuffer('enum ${value.name} {\n');

  if (value.reservedNumbers.isNotEmpty) {
    buffer.writeln('  reserved ${value.reservedNumbers.join(', ')};');
  }
  if (value.reservedNames.isNotEmpty) {
    buffer.writeln('  reserved ${value.reservedNames.map((String name) => '"$name"').join(', ')};');
  }
  for (final DeclaredProtoEnumMember member in value.values) {
    buffer.writeln('  ${member.name} = ${member.number};');
  }

  buffer.write('}\n');
  return buffer.toString();
}

String _service(DeclaredProtoService service) {
  final StringBuffer buffer = StringBuffer('service ${service.name} {\n');

  for (final DeclaredProtoRpc rpc in service.rpcs) {
    buffer.writeln('  rpc ${rpc.name}(${rpc.request}) returns (${rpc.response});');
  }

  buffer.write('}\n');
  return buffer.toString();
}
