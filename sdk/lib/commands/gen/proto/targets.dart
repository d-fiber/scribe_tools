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

class ProtoTarget {
  const ProtoTarget({
    required this.language,
    required this.pluginName,
    required this.pluginHint,
    required this.outputFlag,
    required this.outputPrefix,
    required this.optionFlag,
    required this.options,
    required this.outputSegments,
  });

  final String language;
  final String pluginName;
  final String pluginHint;
  final String outputFlag;
  final String outputPrefix;
  final String? optionFlag;
  final List<String> options;
  final List<String> outputSegments;

  Directory outputDirectory(String sdkRoot) =>
      Directory(p.joinAll(<String>[sdkRoot, language, ...outputSegments]));

  File? locatePlugin(String sdkRoot) {
    for (final String candidate in _pluginCandidates(sdkRoot)) {
      final File file = File(candidate);
      if (file.existsSync()) return file;
    }
    return null;
  }

  List<String> _pluginCandidates(String sdkRoot) {
    final String home = Platform.environment['HOME'] ?? '';
    return <String>[
      p.join(sdkRoot, language, 'node_modules', '.bin', pluginName),
      p.join(home, '.pub-cache', 'bin', pluginName),
      '/opt/homebrew/bin/$pluginName',
      '/usr/local/bin/$pluginName',
    ];
  }

  List<String> protocArguments(String sdkRoot, File plugin) {
    final String output = outputDirectory(sdkRoot).path;
    final List<String> arguments = <String>[
      '--plugin=$pluginName=${plugin.path}',
      '--$outputFlag=$outputPrefix$output',
    ];
    final String? flag = optionFlag;
    if (flag != null && options.isNotEmpty) {
      arguments.add('--$flag=${options.join(',')}');
    }
    return arguments;
  }
}

const List<ProtoTarget> protoTargets = <ProtoTarget>[
  ProtoTarget(
    language: 'js',
    pluginName: 'protoc-gen-es',
    pluginHint: 'npm install --prefix scribe/sdk/js @bufbuild/protobuf @bufbuild/protoc-gen-es',
    outputFlag: 'es_out',
    outputPrefix: '',
    optionFlag: 'es_opt',
    options: <String>['target=ts', 'import_extension=.ts', 'json_types=true'],
    outputSegments: <String>['gen'],
  ),
  ProtoTarget(
    language: 'dart',
    pluginName: 'protoc-gen-dart',
    pluginHint: 'dart pub global activate protoc_plugin',
    outputFlag: 'dart_out',
    outputPrefix: '',
    optionFlag: null,
    options: <String>[],
    outputSegments: <String>['lib', 'gen'],
  ),
];
