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
import '../../../../../core/paths/tree.g.dart';
import '../../../../../ops/config.dart';
import '../../../sql_scanner.dart';
import '../../sql/sql_type_mapper.dart';
import '../../sql/table_schema.dart';

const Set<String> _skip = <String>{};

// Une table « appartient » à quelqu'un dès qu'elle porte une clé étrangère
// user_id → app_users ou admin_id → admin_users ; les deux tables racines
// s'appartiennent à elles-mêmes via leur clé primaire. C'est cette map que le
// builder consomme pour injecter le filtre du propriétaire à la place de la RLS
// (voir caleb/clients/database/query/scope.ts).
final RegExp _userOwnedRe = RegExp(r'\buser_id\b[^,]*references\s+public\.internal_t__app_users', caseSensitive: false);
final RegExp _adminOwnedRe = RegExp(
  r'\badmin_id\b[^,]*references\s+public\.internal_t__admin_users',
  caseSensitive: false,
);

const Map<String, String> _rootOwners = <String, String>{
  'internal_t__app_users': 'user_id',
  'internal_t__admin_users': 'admin_id',
};

String? _ownerColumnOf(String table, String body) {
  final String? root = _rootOwners[table];
  if (root != null) return root;
  if (_userOwnedRe.hasMatch(body)) return 'user_id';
  if (_adminOwnedRe.hasMatch(body)) return 'admin_id';
  return null;
}

List<String> _generatedHeader(String bin) => <String>[
  '// This file is auto-generated do not edit manually.',
  '// Run: $bin gen code',
  '',
];

List<String> _renderRowLines(String bin, List<String> names, Map<String, TableSchema> tables) {
  final Set<String> usedEnums = <String>{};
  for (final String t in names) {
    for (final Col col in tables[t]!.cols) {
      if (col.enumName != null) usedEnums.add(col.enumName!.replaceFirst('[]', ''));
    }
  }

  final List<String> lines = _generatedHeader(bin);

  if (usedEnums.isNotEmpty) {
    final List<String> sortedEnums = usedEnums.toList()..sort();
    lines.add('import type {');
    for (final String e in sortedEnums) {
      lines.add('  $e,');
    }
    lines.add('} from "@scribe/core/contracts/enums.ts";');
    lines.add('');
  }

  for (final String t in names) {
    final TableSchema schema = tables[t]!;
    lines.add('export interface ${t.toPascalCase()}Row {');
    for (final Col col in schema.cols) {
      lines.add('  ${col.name}: ${col.ts};');
    }
    lines.add('}');
    lines.add('');
  }

  return lines;
}

/// Section relations (marqueurs `@generated:relations:*`) déjà présente dans
/// [tablesTsFile], lue telle quelle — peut être périmée d'un run précédent
/// (generateRelations() tourne après generateTables() dans code_command.dart),
/// accepté comme limitation connue plutôt qu'une dépendance d'ordre stricte
/// entre les deux générateurs.
///
/// C'est un fichier entier (`gen/relations.ts`, 100 % généré) : plus de section
/// entre marqueurs depuis la scission de rest/ en gen/ + fichiers écrits à la
/// main (voir la version cli, identique sur ce point).
Future<String> _readGeneratedRelations(File file) async {
  if (!await file.exists()) return '';
  return await file.readAsString();
}

/// `gen/tables.ts` : une méthode par table kernel, sur une classe qui hérite de
/// la base écrite à la main (`@scribe/core/clients/database/tables.ts`).
List<String> _renderKernelTables(
  String bin,
  List<String> tableNames,
  bool Function(String) hasRel,
) {
  final List<String> relations = tableNames.where(hasRel).map((String t) => '${t.toPascalCase()}Relations').toList()
    ..sort();

  return <String>[
    ..._generatedHeader(bin),
    'import { from, TablesBase } from "@scribe/core/clients/database/tables.ts";',
    'import type { TypedQueryBuilder } from "@scribe/core/clients/database/query/builder.ts";',
    if (relations.isNotEmpty) ...<String>[
      'import type {',
      for (final String r in relations) '  $r,',
      '} from "./relations.ts";',
    ],
    'import type {',
    for (final String t in tableNames) '  ${t.toPascalCase()}Row,',
    '} from "./rows.ts";',
    '',
    'export class Tables extends TablesBase {',
    for (final String table in tableNames) ...<String>[
      '  $table(): TypedQueryBuilder<${table.toPascalCase()}Row${hasRel(table) ? ', ${table.toPascalCase()}Row, ${table.toPascalCase()}Relations' : ''}> {',
      '    return from<${table.toPascalCase()}Row${hasRel(table) ? ', ${table.toPascalCase()}Relations' : ''}>(this.db, "$table");',
      '  }',
    ],
    '}',
    '',
  ];
}

/// `gen/metadata.ts` : le propriétaire de chaque table, seule métadonnée de
/// schéma dont le builder a besoin. Données pures — le registre vit dans
/// `schema.ts`.
List<String> _renderMetadata(String bin, List<String> tableNames, Map<String, String> owners) {
  final List<String> ownerKeys = tableNames.where(owners.containsKey).toList()..sort();

  return <String>[
    ..._generatedHeader(bin),
    'export const TABLE_OWNERS: Record<string, string> = {',
    for (final String t in ownerKeys) '  $t: "${owners[t]}",',
    '};',
    '',
  ];
}

Future<void> generateTables() async {
  const Log log = Log('gen');

  await loadComposites();
  log.info('${composites.length} composite types loaded');

  final Map<String, TableSchema> tables = <String, TableSchema>{};
  final Map<String, String> owners = <String, String>{};

  // Kernel-only : jamais lib/db/init/ (voir generateEnums()/generateRelations()
  // pour la même règle). Toutes les tables scannées ici sont donc kernel par
  // construction — pas de détection/filtrage project nécessaire, contrairement
  // à la version cli qui distingue kernelTableNames de projectTableNames.
  Future<void> scanTables(File file) async {
    final String sql = await file.readAsString();
    for (final RegExpMatch m in createTableRe.allMatches(sql)) {
      final String tableName = m.group(1)!;
      if (tables.containsKey(tableName)) continue;
      final String body = m.group(2)!;
      tables[tableName] = TableSchema(tableName, parseColumns(body));
      final String? owner = _ownerColumnOf(tableName, body);
      if (owner != null) owners[tableName] = owner;
    }
    for (final RegExpMatch m in alterTableAddColumnRe.allMatches(sql)) {
      final String tableName = m.group(1)!;
      final TableSchema? schema = tables[tableName];
      if (schema == null) continue;
      schema.cols.addAll(parseAlterAddColumns(m.group(2)!));
    }
  }

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, scanTables);
  }
  await walkSqlFiles(Directory(p.join(InfraFiles.root.path, 'scribe/host/caleb/db/migrations')), scanTables);

  final List<String> kernelTableNames = tables.keys.toList()..sort();

  final String bin = Config.read().get('NAME').toSnakeCase();

  // Tout ce qui est généré côté kernel vit dans rest/gen/, réécrit en entier :
  // aucune section écrite à la main à préserver, donc plus aucun marqueur
  // @generated à patcher. Ce qui reste écrit à la main (from()/TablesBase dans
  // rest/tables.ts, le registre de rest/schema.ts) n'est jamais touché ici.
  final FoundationFunctionsDependenciesDatabaseRest rest = InfraFiles.tree.scribe.host.dependencies.database.rest;
  await rest.gen.directory.create(recursive: true);

  await rest.gen.rowsTs.writeAsString(_renderRowLines(bin, kernelTableNames, tables).join('\n'));

  final String kernelRelSection = await _readGeneratedRelations(rest.gen.relationsTs);
  bool hasRel(String t) => kernelRelSection.contains('type ${t.toPascalCase()}Relations =');

  final List<String> sortedMethods = kernelTableNames.where((String t) => !_skip.contains(t)).toList()..sort();
  await rest.gen.tablesTs.writeAsString(_renderKernelTables(bin, sortedMethods, hasRel).join('\n'));

  await rest.gen.metadataTs.writeAsString(_renderMetadata(bin, kernelTableNames, owners).join('\n'));

  log.info('${kernelTableNames.length} kernel Row interfaces → gen/rows.ts');
  log.info('${sortedMethods.length} kernel table methods → gen/tables.ts');
  log.info('${kernelTableNames.where(owners.containsKey).length} kernel table owners → gen/metadata.ts');
}
