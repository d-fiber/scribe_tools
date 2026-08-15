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

import 'package:args/command_runner.dart';

import 'protoc.dart';
import 'targets.dart';

const String _checkFlag = 'check';
const String _languageOption = 'language';

class GenProtoCommand extends Command<dynamic> {
  GenProtoCommand() {
    argParser
      ..addFlag(
        _checkFlag,
        negatable: false,
        help: 'Validate the contract without writing any stub.',
      )
      ..addOption(
        _languageOption,
        allowed: protoTargets.map((ProtoTarget target) => target.language),
        help: 'Generate a single SDK target instead of all of them.',
      );
  }

  @override
  final String name = 'proto';

  @override
  final String description =
      'Validate scribe/**/protocol/*.proto and generate the per-language stubs '
      'into scribe/sdk/<language>/gen/ (host contract, no lib/ awareness).';

  @override
  Future<void> run() async {
    await requireProtoc();

    final ProtoSources sources = ProtoSources.discover();
    await validateProtoSources(sources);

    if (argResults?[_checkFlag] as bool? ?? false) return;

    for (final ProtoTarget target in _selectedTargets()) {
      await generateTarget(sources, target);
    }
  }

  List<ProtoTarget> _selectedTargets() {
    final String? language = argResults?[_languageOption] as String?;
    if (language == null) return protoTargets;
    return protoTargets.where((ProtoTarget target) => target.language == language).toList();
  }
}
