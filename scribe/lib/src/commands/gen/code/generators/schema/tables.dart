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

import '../../../sql_scanner.dart';
import '../../relations/relations_markers.dart';
import '../../sql/sql_type_mapper.dart';
import '../../sql/table_schema.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/base/common.dart';

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

List<String> _renderRowLines(
  String bin,
  List<String> names,
  Map<String, TableSchema> tables,
  Set<String> projectEnums, {
  Map<String, List<Col>> extensions = const <String, List<Col>>{},
}) {
  final Set<String> usedEnums = <String>{};
  void collectEnums(Iterable<Col> cols) {
    for (final Col col in cols) {
      if (col.enumName != null) usedEnums.add(col.enumName!.replaceFirst('[]', ''));
    }
  }

  for (final String t in names) {
    collectEnums(tables[t]!.cols);
  }
  for (final List<Col> cols in extensions.values) {
    collectEnums(cols);
  }

  final List<String> lines = _generatedHeader(bin);
  lines.addAll(_renderEnumImports(usedEnums, projectEnums));

  for (final String t in names) {
    final TableSchema schema = tables[t]!;
    lines.add('export interface ${t.toPascalCase()}Row {');
    for (final Col col in schema.cols) {
      lines.add('  ${col.name}: ${col.ts};');
    }
    lines.add('}');
    lines.add('');
  }

  final List<String> extended = extensions.keys.toList()..sort();
  for (final String t in extended) {
    lines.add('export interface ${t.toPascalCase()}ProjectColumns {');
    for (final Col col in extensions[t]!) {
      lines.add('  ${col.name}: ${col.ts};');
    }
    lines.add('}');
    lines.add('');
  }

  return lines;
}

/// Un enum vient soit de `caleb/db/init/` (kernel), soit de `lib/db/init/`
/// (project) jamais des deux, les deux racines ne peuvent pas déclarer le
/// même type. L'import est donc routé nom par nom. Côté kernel [projectEnums]
/// est vide par construction : la fuite qui rendait ça possible (un ALTER
/// project sur une table kernel) est neutralisée dans generateTables().
/// La meme surface que `ProjectTables`, mais batie sur `RestQuery` du SDK.
///
/// Un worker ne peut importer ni `@scribe/core/` ni `@scribe/host/` : il tourne
/// dans un autre process, potentiellement sans l'hote sur le disque. Les Row des
/// tables kernel etendues sont donc redeclarees ici a partir du meme SQL, au
/// lieu d'etre importees. Voir `.claude/scripts/cli/gen/code.md` § « worker.ts ».
List<String> _renderWorkerTables(
  String bin,
  List<String> projectTables,
  List<String> extendedTables,
  Map<String, TableSchema> tables,
  Map<String, List<Col>> extensions,
  Set<String> projectEnums,
) {
  final Set<String> usedEnums = <String>{};
  for (final String t in extendedTables) {
    for (final Col col in tables[t]!.cols) {
      if (col.enumName != null) usedEnums.add(col.enumName!.replaceFirst('[]', ''));
    }
  }

  String workerRow(String t) => '${t.toPascalCase()}KernelColumns & ${t.toPascalCase()}ProjectColumns';

  return <String>[
    ..._generatedHeader(bin),
    'import { RestQuery } from "@scribe/sdk";',
    ..._renderEnumImports(usedEnums, projectEnums),
    'import type {',
    for (final String t in projectTables) '  ${t.toPascalCase()}Row,',
    for (final String t in extendedTables) '  ${t.toPascalCase()}ProjectColumns,',
    '} from "./_rows.generated.ts";',
    '',
    for (final String t in extendedTables) ...<String>[
      'export interface ${t.toPascalCase()}KernelColumns {',
      for (final Col col in tables[t]!.cols) '  ${col.name}: ${col.ts};',
      '}',
      '',
    ],
    'export class WorkerTables {',
    for (final String t in projectTables) ...<String>[
      '  $t(): RestQuery<${t.toPascalCase()}Row> {',
      '    return new RestQuery<${t.toPascalCase()}Row>("$t");',
      '  }',
    ],
    for (final String t in extendedTables) ...<String>[
      '  $t(): RestQuery<${workerRow(t)}> {',
      '    return new RestQuery<${workerRow(t)}>("$t");',
      '  }',
    ],
    '}',
    '',
    'export const rest = new WorkerTables();',
    '',
  ];
}

List<String> _renderEnumImports(Set<String> usedEnums, Set<String> projectEnums) {
  if (usedEnums.isEmpty) return const <String>[];

  final List<String> kernel = usedEnums.where((String e) => !projectEnums.contains(e)).toList()..sort();
  final List<String> project = usedEnums.where(projectEnums.contains).toList()..sort();

  return <String>[
    // Les enums kernel viennent du SDK et non de l'hote : ce fichier est lu
    // par `lib/api/` (in-process) ET par `lib/src/` (worker), et un worker ne
    // peut pas importer `@scribe/core/`. Le SDK est le seul point commun.
    if (kernel.isNotEmpty) ...<String>[
      'import type {',
      for (final String e in kernel) '  $e,',
      '} from "@scribe/sdk";',
    ],
    if (project.isNotEmpty) ...<String>[
      'import type {',
      for (final String e in project) '  $e,',
      '} from "${globals.project.generatedAlias}enums.ts";',
    ],
    '',
  ];
}

/// Les types `<X>Relations` tels qu'écrits par le run précédent de
/// generateRelations() (qui tourne APRÈS generateTables() dans
/// code_command.dart) — donc potentiellement périmés d'un run, accepté comme
/// limitation connue plutôt qu'une dépendance d'ordre stricte entre les deux
/// générateurs.
///
/// Côté kernel c'est un fichier entier (`gen/relations.ts`, 100 % généré) ;
/// côté project c'est encore une section entre marqueurs dans son `tables.ts`.
Future<String> _readGeneratedRelations(File file) async {
  if (!await file.exists()) return '';
  return await file.readAsString();
}

Future<String> _readRelationsSection(File tablesTsFile) async {
  final String src = await _readGeneratedRelations(tablesTsFile);
  final int start = src.indexOf(relationsMarkerStart);
  final int end = src.indexOf(relationsMarkerEnd);
  return (start != -1 && end != -1) ? src.substring(start, end) : '';
}

class _PendingAlter {
  _PendingAlter(this.table, this.body, this.isProjectSource);

  final String table;
  final String body;
  final bool isProjectSource;
}

Future<void> generateTables(Set<String> projectEnums) async {

  await loadComposites();
  globals.logger.printStatus('${composites.length} composite types loaded');

  final Map<String, TableSchema> tables = <String, TableSchema>{};
  // Table dont le CREATE TABLE d'origine vit sous lib/db/init/ (par
  // opposition à un simple ALTER TABLE project sur une table kernel) : exclue
  // des sorties kernel ci-dessous, générée à la place dans
  // le rest/ généré, voir _generateProjectTables().
  final Set<String> projectTableNames = <String>{};
  final Map<String, String> owners = <String, String>{};
  // Colonnes qu'un ALTER TABLE de lib/db/init/ ajoute à une table dont le
  // CREATE vit côté kernel. Elles ne doivent pas entrer dans le Row kernel —
  // sinon rest/gen/rows.ts référence des enums project et le SDK ne compile
  // plus seul. Résolues après le scan complet, quand projectTableNames est
  // connu, puis rendues côté project en surcharge — voir _renderExtensions().
  final List<_PendingAlter> alters = <_PendingAlter>[];

  Future<void> scanTables(File file, {bool isProjectSource = false}) async {
    final String sql = await file.readAsString();
    for (final RegExpMatch m in createTableRe.allMatches(sql)) {
      final String tableName = m.group(1)!;
      if (tables.containsKey(tableName)) continue;
      final String body = m.group(2)!;
      tables[tableName] = TableSchema(tableName, parseColumns(body));
      final String? owner = _ownerColumnOf(tableName, body);
      if (owner != null) owners[tableName] = owner;
      if (isProjectSource) projectTableNames.add(tableName);
    }
    for (final RegExpMatch m in alterTableAddColumnRe.allMatches(sql)) {
      alters.add(_PendingAlter(m.group(1)!, m.group(2)!, isProjectSource));
    }
  }

  for (final Directory root in kernelSqlRoots()) {
    await walkSqlFiles(root, scanTables);
  }
  await walkSqlFiles(globals.project.init, (File f) => scanTables(f, isProjectSource: true));

  final Map<String, List<Col>> projectExtensions = <String, List<Col>>{};
  for (final _PendingAlter alter in alters) {
    final TableSchema? schema = tables[alter.table];
    if (schema == null) continue;
    final List<Col> added = parseAlterAddColumns(alter.body);
    if (alter.isProjectSource && !projectTableNames.contains(alter.table)) {
      (projectExtensions[alter.table] ??= <Col>[]).addAll(added);
      continue;
    }
    schema.cols.addAll(added);
  }

  final List<String> sortedTableNames = tables.keys.toList()..sort();
  final List<String> kernelTableNames = sortedTableNames.where((String t) => !projectTableNames.contains(t)).toList();

  final String bin = kToolName;

  // Rien n'est ecrit ici cote SDK : `rest/gen/` est produit par
  // `koko-kernel gen code`, et livre avec le framework. Les tables kernel sont
  // seulement LUES, pour que `ProjectTables` sache de quoi elle herite et pour
  // ne pas redeclarer une table du socle.
  globals.logger.printStatus('${kernelTableNames.length} kernel tables read from the SDK');

  await _generateProjectTables(bin, tables, projectTableNames, owners, projectEnums, projectExtensions);
}

// le rest/ généré : ProjectTables extends Tables
// (kernel), une méthode par table dont le CREATE TABLE vit sous
// lib/db/init/. Mirroir de ce que tables.dart écrit côté kernel (rows,
// méthodes de table, propriétaires) — mais à plat, sans dossier gen/ : côté
// project ces fichiers étaient déjà 100 % générés, la scission kernel n'avait
// donc rien à y séparer. _rows.generated.ts et _owners.ts sont réécrits
// en entier ; tables.ts garde des marqueurs uniquement pour la section
// relations, patchée ensuite par generateRelations() (qui tourne après
// generateTables() dans code_command.dart) — imports/méthodes sont réécrits en
// entier à chaque run.
Future<void> _generateProjectTables(
  String bin,
  Map<String, TableSchema> tables,
  Set<String> projectTableNames,
  Map<String, String> owners,
  Set<String> projectEnums,
  Map<String, List<Col>> extensions,
) async {
  final List<String> sortedProjectTableNames = projectTableNames.toList()..sort();
  if (sortedProjectTableNames.isEmpty && extensions.isEmpty) return;

  await globals.project.generated.sdk.rest.create();

  await globals.project.generated.sdk.rest.rows.writeAsString(
    _renderRowLines(bin, sortedProjectTableNames, tables, projectEnums, extensions: extensions).join('\n'),
  );

  // Lu AVANT d'écraser tables.ts ci-dessous : la section relations project
  // telle qu'elle existait avant ce run (même tolérance à la péremption que
  // côté kernel, voir _readRelationsSection()).
  final String projectRelSection = await _readRelationsSection(globals.project.generated.sdk.rest.tables);
  bool hasRel(String t) => projectRelSection.contains('type ${t.toPascalCase()}Relations =');

  final List<String> ownerLines = <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
    'import { registerTableOwners } from "@scribe/core/clients/database/schema.ts";',
    '',
    'const TABLE_OWNERS: Record<string, string> = {',
    for (final String t in sortedProjectTableNames.where(owners.containsKey)) '  $t: "${owners[t]}",',
    '};',
    '',
    'registerTableOwners(TABLE_OWNERS);',
    '',
  ];
  await globals.project.generated.sdk.rest.owners.writeAsString(ownerLines.join('\n'));

  // Tables kernel qu'un ALTER TABLE de lib/db/init/ étend. ProjectTables
  // redéclare leur accesseur avec le Row kernel intersecté des colonnes
  // project, pour que lib/ voie ses propres colonnes sans que le Row kernel
  // (rest/gen/rows.ts) ait à les connaître.
  final List<String> extendedTables = extensions.keys.toList()..sort();
  String extendedRow(String t) => '${t.toPascalCase()}Row & ${t.toPascalCase()}ProjectColumns';

  final List<String> projectLines = <String>[
    '// This file is auto-generated do not edit manually.',
    '// Run: $bin gen code',
    '',
    // Side-effect : enregistre TABLE_OWNERS project auprès du registre de
    // rest/schema.ts dès que ProjectTables est importé.
    'import "./_owners.ts";',
    'import { Tables } from "@scribe/host/dependencies/database/rest/gen/tables.ts";',
    'import { TypedQueryBuilder } from "@scribe/core/clients/database/query/builder.ts";',
    if (extendedTables.isNotEmpty) ...<String>[
      'import type {',
      for (final String t in extendedTables) '  ${t.toPascalCase()}Row,',
      '} from "@scribe/host/dependencies/database/rest/gen/rows.ts";',
    ],
    'import type {',
    for (final String t in sortedProjectTableNames) '  ${t.toPascalCase()}Row,',
    for (final String t in extendedTables) '  ${t.toPascalCase()}ProjectColumns,',
    '} from "./_rows.generated.ts";',
    '',
    relationsMarkerStart,
    relationsMarkerEnd,
    '',
    'export class ProjectTables extends Tables {',
    for (final String table in sortedProjectTableNames) ...<String>[
      '  $table(): TypedQueryBuilder<${table.toPascalCase()}Row${hasRel(table) ? ', ${table.toPascalCase()}Row, ${table.toPascalCase()}Relations' : ''}> {',
      '    return new TypedQueryBuilder<${table.toPascalCase()}Row, ${table.toPascalCase()}Row${hasRel(table) ? ', ${table.toPascalCase()}Relations' : ''}>(this.db, "$table");',
      '  }',
    ],
    for (final String table in extendedTables) ...<String>[
      '  override $table(): TypedQueryBuilder<${extendedRow(table)}> {',
      '    return new TypedQueryBuilder<${extendedRow(table)}, ${extendedRow(table)}>(this.db, "$table");',
      '  }',
    ],
    '}',
    '',
  ];

  await globals.project.generated.sdk.rest.tables.writeAsString(projectLines.join('\n'));

  // Mirroir de @scribe/clients/database/rest/rest.ts : une seule surface,
  // `rest`, sur le service role. Le filtrage par propriétaire n'est plus une
  // affaire de portée de client mais du builder, qui injecte `user_id`/`admin_id`
  // depuis l'identité de la requête (voir caleb/clients/database/query/scope.ts).
  final List<String> clientLines = <String>[
    ..._generatedHeader(bin),
    // Import à effet de bord : _owners.ts appelle registerTableOwners() au
    // chargement. Sans lui, aucune table project n'a de propriétaire connu,
    // donc aucune n'est bornée à son utilisateur.
    'import "./_owners.ts";',
    'import { PostgrestClients } from "@scribe/core/clients/database/client.ts";',
    'import { ProjectTables } from "./tables.ts";',
    '',
    'export class ProjectRestClient extends ProjectTables {}',
    '',
    'export const rest = new ProjectRestClient(() => PostgrestClients.service());',
    '',
  ];
  await globals.project.generated.sdk.rest.client.writeAsString(clientLines.join('\n'));

  await globals.project.generated.sdk.rest.worker.writeAsString(
    _renderWorkerTables(
      bin,
      sortedProjectTableNames,
      extendedTables,
      tables,
      extensions,
      projectEnums,
    ).join('\n'),
  );

  globals.logger.printStatus(
    '${sortedProjectTableNames.length + extendedTables.length} worker table methods → '
    '${globals.project.generatedDirectoryName}/sdk/js/rest/worker.ts',
  );

  globals.logger.printStatus(
    '${sortedProjectTableNames.length} project Row interfaces + table methods, '
    '${sortedProjectTableNames.where(owners.containsKey).length} project table owners '
    '→ ${globals.project.generatedDirectoryName}/sdk/js/rest/',
  );
}
