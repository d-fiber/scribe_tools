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


import 'package:file/file.dart';

import 'package:change_case/change_case.dart';
import 'package:path/path.dart' as p;

import '../../../sql_scanner.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/base/common.dart';

class _ParsedEnum {
  _ParsedEnum(this.name, this.values);

  final String name;
  final List<String> values;
}

final RegExp _enumRe = RegExp(r'create\s+type\s+public\.(\w+)\s+as\s+enum\s*\(([\s\S]*?)\);', caseSensitive: false);

final RegExp _valueRe = RegExp(r"'([^']+)'");

/// Renvoie les noms PascalCase des enums issus de `lib/db/init/`. generateTables()
/// s'en sert pour router chaque import : un enum project s'importe depuis
/// `@artefacts/enums.ts`, jamais depuis `@scribe/core/contracts/enums.ts`.
Future<Set<String>> generateEnums() async {

  Future<List<_ParsedEnum>> scan(Iterable<Directory> roots) async {
    final List<_ParsedEnum> found = <_ParsedEnum>[];

    Future<void> collect(File file) async {
      if (!p.basename(file.path).contains('enum')) return;
      final String sql = await file.readAsString();
      for (final RegExpMatch match in _enumRe.allMatches(sql)) {
        final List<String> values = _valueRe.allMatches(match.group(2)!).map((RegExpMatch m) => m.group(1)!).toList();
        found.add(_ParsedEnum(match.group(1)!, values));
      }
    }

    for (final Directory root in roots) {
      await walkSqlFiles(root, collect);
    }
    found.sort((_ParsedEnum a, _ParsedEnum b) => a.name.compareTo(b.name));
    return found;
  }

  final List<_ParsedEnum> kernelEnums = await scan(kernelSqlRoots());
  final List<_ParsedEnum> projectEnums = await scan(<Directory>[globals.project.init]);

  final String bin = kToolName;

  // Les enums du socle ne sont que LUS : `caleb/contracts/enums.ts` est ecrit
  // par `koko-kernel gen code` et livre avec le framework. Ils servent ici a
  // router chaque import nom par nom entre `@scribe/core/` et `@artefacts/`.
  globals.logger.printStatus('${kernelEnums.length} kernel enums read from the SDK');

  if (projectEnums.isEmpty) return <String>{};

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.enums.writeAsString(
    _render(bin, projectEnums, withHelper: false).join('\n'),
  );
  globals.logger.printStatus('${projectEnums.length} project enums → ${globals.project.generatedDirectoryName}/sdk/js/enums.ts');

  return projectEnums.map((_ParsedEnum e) => e.name.toPascalCase()).toSet();
}

// enumValues() est déclarée une seule fois, côté kernel : le fichier project la
// réexporte pour que `@artefacts/enums.ts` soit un point d'import complet,
// sans obliger l'appelant à savoir de quelle racine SQL vient chaque enum.
List<String> _render(String bin, List<_ParsedEnum> enums, {required bool withHelper}) {
  final List<String> lines = <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
  ];

  if (withHelper) {
    lines.addAll(<String>[
      'export function enumValues<T extends object>(e: T): T[keyof T][] {',
      '  return Object.values(e) as T[keyof T][];',
      '}',
      '',
    ]);
  } else {
    lines.addAll(<String>[
      'export { enumValues } from "@scribe/core/contracts/enums.ts";',
      '',
    ]);
  }

  for (final _ParsedEnum e in enums) {
    lines.add('export enum ${e.name.toPascalCase()} {');
    for (final String v in e.values) {
      lines.add('  ${v.toUpperCase()} = "$v",');
    }
    lines.add('}');
    lines.add('');
  }

  return lines;
}
