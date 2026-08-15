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

// Shared by mail_strings.dart and sms_strings.dart : both walk a
// lib/public/<kind>/templates/ subtree the same way, only the
// root node and the log label differ.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/logger.dart';
import '../../../core/file_system_entity/node.dart';
import '../../../core/file_system_entity/paths.dart';
import '../../../core/file_system_entity/source.dart';
import 'entries.dart';
import 'ts_renderer.dart';

Future<void> generateTemplateStrings(Node templatesRoot, String label) async {
  const Log log = Log('public');

  final List<Source> files = await templatesRoot.list();
  final List<Source> csvFiles = files.where((Source s) => p.basename(s.path) == 'strings.csv').toList()
    ..sort((Source a, Source b) => a.path.compareTo(b.path));

  if (csvFiles.isEmpty) {
    log.info('No strings.csv found under ${p.relative(templatesRoot.path, from: Paths.root.path)}/.');
    return;
  }

  for (final Source csvFile in csvFiles) {
    final String dir = p.dirname(csvFile.path);
    final String sourcePath = p.relative(csvFile.path, from: Paths.root.path);

    final String csv = await File(csvFile.path).readAsString();
    final MailL10nSource source = parseMailEntries(csv, log, sourcePath);
    final MailL10nModule module = renderMailL10nModule(source, sourcePath);

    final String arbDir = p.join(dir, 'arb');
    await Directory(arbDir).create(recursive: true);
    for (final MapEntry<String, String> file in module.localeFiles.entries) {
      await File(p.join(arbDir, '${file.key}.ts')).writeAsString(file.value);
    }
    await File(p.join(dir, 'strings.ts')).writeAsString(module.strings);

    final String localeFileNames = source.locales.map((String l) => 'arb/$l.ts').join(', ');
    log.info(
      '${p.relative(dir, from: Paths.root.path)}: ${source.entries.length} string(s) × '
      '${source.locales.length} language(s) (${source.locales.join(", ")}) → {$localeFileNames,strings.ts}',
    );
  }

  log.info('${csvFiles.length} $label template(s) generated.');
}
