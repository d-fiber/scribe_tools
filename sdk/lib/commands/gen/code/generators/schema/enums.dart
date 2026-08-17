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

import 'package:change_case/change_case.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/logger.dart';
import '../../../../../core/paths/infra_files.dart';
import '../../../../../ops/config.dart';
import '../../../sql_scanner.dart';

class _ParsedEnum {
  _ParsedEnum(this.name, this.values);

  final String name;
  final List<String> values;
}

final RegExp _enumRe = RegExp(r'create\s+type\s+public\.(\w+)\s+as\s+enum\s*\(([\s\S]*?)\);', caseSensitive: false);

final RegExp _valueRe = RegExp(r"'([^']+)'");

Future<void> generateEnums() async {
  const Log log = Log('gen');
  final List<_ParsedEnum> enums = <_ParsedEnum>[];

  Future<void> collect(File file) async {
    if (!p.basename(file.path).contains('enum')) return;
    final String sql = await file.readAsString();
    for (final RegExpMatch match in _enumRe.allMatches(sql)) {
      final List<String> values = _valueRe.allMatches(match.group(2)!).map((RegExpMatch m) => m.group(1)!).toList();
      enums.add(_ParsedEnum(match.group(1)!, values));
    }
  }

  // Kernel-only, so never lib/db/init/: this CLI has no such path in its
  // InfrastructureRoot, since tool/generate_paths.dart leaves lib/ out of the
  // scan. The shipped CLI is the one that scans kernel and project together.
  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, collect);
  }
  await walkSqlFiles(Directory(p.join(InfraFiles.root.path, 'scribe/host/caleb/db/migrations')), collect);

  enums.sort((_ParsedEnum a, _ParsedEnum b) => a.name.compareTo(b.name));

  final String bin = Config.read().get('NAME').toSnakeCase();
  final List<String> lines = <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
    'export function enumValues<T extends object>(e: T): T[keyof T][] {',
    '  return Object.values(e) as T[keyof T][];',
    '}',
    '',
  ];

  for (final _ParsedEnum e in enums) {
    lines.add('export enum ${e.name.toPascalCase()} {');
    for (final String v in e.values) {
      lines.add('  ${v.toUpperCase()} = "$v",');
    }
    lines.add('}');
    lines.add('');
  }

  await InfraFiles.tree.scribe.host.core.contracts.enumsTs.writeAsString(lines.join('\n'));

  // Seconde sortie, meme contenu : un worker ne peut pas importer l'hote, or
  // les Row generes cote projet portent ces enums. Le SDK est le seul endroit
  // que les deux atteignent. Voir `.claude/scribe/sdk/global.md` § « Le schema
  // que le SDK expose ».
  final File sdkEnums = File(p.join(InfraFiles.root.path, 'scribe/sdk/js/gen/schema/enums.ts'));
  await sdkEnums.parent.create(recursive: true);
  await sdkEnums.writeAsString(lines.join('\n'));

  log.info('${enums.length} enums generated → caleb/contracts/enums.ts + sdk/js/gen/schema/enums.ts');
}
