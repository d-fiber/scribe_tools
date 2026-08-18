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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/exception.dart';
import '../../../core/logger.dart';
import '../../../core/paths/infra_files.dart';
import 'targets.dart';

const Log _log = Log('gen:proto');

const String _protocolDirectory = 'protocol';
const String _protoExtension = '.proto';

class ProtoSources {
  const ProtoSources(this.repositoryRoot, this.sdkRoot, this.files);

  final String repositoryRoot;
  final String sdkRoot;
  final List<String> files;

  static ProtoSources discover() {
    final String repositoryRoot = InfraFiles.root.path;
    final Directory scribe = Directory(p.join(repositoryRoot, 'scribe'));
    if (!scribe.existsSync()) {
      throw CliException('[gen:proto] ${scribe.path} is missing.');
    }

    final List<String> files = scribe
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((File file) => file.path)
        .where(_isProtocolSource)
        .map((String path) => p.relative(path, from: repositoryRoot))
        .toList()
      ..sort();

    if (files.isEmpty) {
      throw CliException('[gen:proto] no .proto found under ${scribe.path}/**/protocol/.');
    }

    return ProtoSources(repositoryRoot, p.join(scribe.path, 'sdk'), files);
  }

  // A package groups its contracts by subject, so a .proto sits under
  // `protocol/<subject>/` rather than directly in `protocol/`. Matching any
  // segment keeps both layouts discoverable.
  static bool _isProtocolSource(String path) =>
      p.extension(path) == _protoExtension &&
      p.split(p.dirname(path)).contains(_protocolDirectory);
}

Future<void> validateProtoSources(ProtoSources sources) async {
  final ProcessResult result = await Process.run(
    'protoc',
    <String>['-I', sources.repositoryRoot, '--descriptor_set_out=${_nullDevice()}', ...sources.files],
    workingDirectory: sources.repositoryRoot,
  );
  if (result.exitCode != 0) {
    throw CliException('[gen:proto] protoc rejected the contract:\n${result.stderr}');
  }
  _log.info('${sources.files.length} .proto validated.');
}

Future<void> generateTarget(ProtoSources sources, ProtoTarget target) async {
  final File? plugin = target.locatePlugin(sources.sdkRoot);
  if (plugin == null) {
    _log.warn('${target.language}: plugin ${target.pluginName} not found, target skipped.');
    _log.warn('${target.language}: install it with `${target.pluginHint}`.');
    return;
  }

  final Directory output = target.outputDirectory(sources.sdkRoot);
  if (output.existsSync()) output.deleteSync(recursive: true);
  output.createSync(recursive: true);

  final ProcessResult result = await Process.run(
    'protoc',
    <String>[
      '-I',
      sources.repositoryRoot,
      ...target.protocArguments(sources.sdkRoot, plugin),
      ...sources.files,
    ],
    workingDirectory: sources.repositoryRoot,
  );

  if (result.exitCode != 0) {
    throw CliException('[gen:proto] ${target.language} generation failed:\n${result.stderr}');
  }

  final int emitted = output.listSync(recursive: true).whereType<File>().length;
  _log.info('${target.language}: $emitted files written to ${p.relative(output.path, from: sources.repositoryRoot)}.');
}

Future<void> requireProtoc() async {
  final ProcessResult result = await Process.run('protoc', <String>['--version']);
  if (result.exitCode != 0) {
    throw CliException('[gen:proto] protoc is not installed run `brew install protobuf`.');
  }
  _log.info('using ${(result.stdout as String).trim()}.');
}

String _nullDevice() => Platform.isWindows ? 'NUL' : '/dev/null';
