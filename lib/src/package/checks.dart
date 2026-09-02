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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/declares.dart';
import 'package:scribe_tools/src/package/dependency_source.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/workspace.dart';

/// One thing a package gets wrong, in the sentence the tool prints.
class Problem {
  /// Records that [package] gets [message] wrong.
  const Problem(this.package, this.message);

  /// The package the problem belongs to.
  final String package;

  /// What is wrong, said plainly enough to be acted on without opening the source.
  final String message;

  @override
  String toString() => '$package: $message';
}

/// Everything wrong with [packages], empty when there is nothing.
///
/// These are the checks that need the tree, which is what separates them from the
/// ones a manifest fails on its own: a name and a version are wrong as they are
/// read, whereas a missing directory is only wrong against the files around it.
List<Problem> check(List<DiscoveredPackage> packages) {
  final List<Problem> problems = <Problem>[];
  final Map<String, DiscoveredPackage> known = <String, DiscoveredPackage>{
    for (final DiscoveredPackage found in packages) found.name: found,
  };

  problems
    ..addAll(_duplicates(packages))
    ..addAll(_declares(packages));

  for (final DiscoveredPackage found in packages) {
    problems
      ..addAll(problemsWithin(found))
      ..addAll(_dependencies(found, known));
  }

  return problems;
}

/// Everything wrong with [found] on its own, without looking at its neighbours.
///
/// It is what a package has to answer before it is resolved into anything. The checks left out are
/// the ones that need the other packages, a duplicate name, a dependency and a bucket two entries
/// both open, none of which can be judged from a single directory.
List<Problem> problemsWithin(DiscoveredPackage found) => <Problem>[
  ..._misplaced(found),
  ...layoutProblems(found.directory, found.name).map((String missing) => Problem(found.name, missing)),
  ..._ownerIndexes(found),
];

List<Problem> _duplicates(List<DiscoveredPackage> packages) {
  final Map<String, String> seen = <String, String>{};
  final List<Problem> problems = <Problem>[];

  for (final DiscoveredPackage found in packages) {
    final String? first = seen[found.name];
    if (first == null) {
      seen[found.name] = found.directory;
      continue;
    }
    problems.add(Problem(found.name, 'two packages call themselves "${found.name}": $first and ${found.directory}.'));
  }

  return problems;
}

List<Problem> _misplaced(DiscoveredPackage found) {
  final String directory = p.basename(found.directory);
  if (directory == found.name) return const <Problem>[];

  return <Problem>[
    Problem(
      found.name,
      'it declares itself "${found.name}" and lives in "$directory". A package is mounted under the '
      'name of its directory, so the two have to match.',
    ),
  ];
}

/// Everything [found] asked another package for that the tree cannot answer.
///
/// What a package needs to run its own suite is held to the same rule as what it depends on: it
/// names a package or it names nothing, and a suite written against a package nobody wrote fails
/// the same way a consumer would. Every [SdkSource] entry is checked against [known], since
/// `dependencies:` no longer holds anything but packages: a redis client a package plainly
/// imports is not named here at all.
///
/// A [PathSource] or a [GitSource] is not checked here at all: neither carries a version to
/// compare, and a `git:` entry would otherwise need the network this command never touches.
/// Whether either actually answers is `scribe forge`'s question, in `resolution.dart`.
List<Problem> _dependencies(DiscoveredPackage found, Map<String, DiscoveredPackage> known) {
  final List<Problem> problems = <Problem>[];
  final Map<String, DependencySource> asked = <String, DependencySource>{
    ...found.manifest.dependencies,
    ...found.manifest.devDependencies,
  };

  for (final MapEntry<String, DependencySource> entry in asked.entries) {
    final DependencySource source = entry.value;
    if (source is! SdkSource) continue;

    final DiscoveredPackage? target = known[entry.key];
    if (target == null) {
      problems.add(Problem(found.name, 'it depends on "${entry.key}", and no package of that name exists.'));
      continue;
    }

    if (allows(source.constraint, target.manifest.version)) continue;
    problems.add(
      Problem(
        found.name,
        'it depends on "${entry.key}" ${source.constraint}, and the copy on hand is ${target.manifest.version}.',
      ),
    );
  }

  return problems;
}

/// Every bucket two packages of [packages] both open through their entry's `declares`.
///
/// A bucket is a name a project reaches by mounting a package, so two packages that open the same
/// one leave a project that mounts both with a file loaded for two meanings at once. Only that
/// collision is checkable here: `scribe gen code` throws the same refusal, but only for the
/// packages a project actually mounts, which is a subset [check] does not see.
List<Problem> _declares(List<DiscoveredPackage> packages) {
  final Map<String, String> openedBy = <String, String>{};
  final List<Problem> problems = <Problem>[];

  for (final DiscoveredPackage found in packages) {
    for (final String bucket in readDeclares(found.directory, found.name).keys) {
      final String? first = openedBy[bucket];
      if (first == null) {
        openedBy[bucket] = found.name;
        continue;
      }
      problems.add(Problem(found.name, 'it opens "$bucket", and so does "$first".'));
    }
  }

  return problems;
}

/// Matches a `registerTableOwners({ ... })` call, capturing its object literal body.
final RegExp _ownersCall = RegExp(r'registerTableOwners\s*\(\s*\{([\s\S]*?)\}\s*\)');

/// Matches one `table: "column"` entry inside a `registerTableOwners` call: a bare or quoted key
/// naming the table, and a double-quoted string naming the column. A computed key, `[x]:`, never
/// matches, since the table name it resolves to cannot be read without running the file.
final RegExp _ownerEntry = RegExp(r'''(?:"([^"]+)"|'([^']+)'|([A-Za-z_$][A-Za-z0-9_$]*))\s*:\s*"([^"]+)"''');

/// Every owner registration `source` declares, table to column.
///
/// The last one written wins when the same table is registered twice in one file, the same rule
/// `registerTableOwners` itself applies at runtime.
Map<String, String> _ownersDeclaredIn(String source) {
  final Map<String, String> owners = <String, String>{};

  for (final RegExpMatch call in _ownersCall.allMatches(source)) {
    for (final RegExpMatch entry in _ownerEntry.allMatches(call.group(1) ?? '')) {
      final String? table = entry.group(1) ?? entry.group(2) ?? entry.group(3);
      final String? column = entry.group(4);
      if (table != null && column != null) owners[table] = column;
    }
  }

  return owners;
}

/// The text of every `.sql` file under `directory`'s `deploy/db/`, concatenated.
String _sqlUnder(String directory) {
  final Directory deploy = globals.fs.directory(p.join(directory, 'deploy', 'db'));
  if (!deploy.existsSync()) return '';

  final StringBuffer sql = StringBuffer();
  for (final FileSystemEntity entity in deploy.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.sql')) sql.writeln(entity.readAsStringSync());
  }
  return sql.toString();
}

/// Whether `sql` indexes `column` of `table`, through a primary key, a unique constraint, or an
/// explicit index whose first column is `column`.
///
/// This reads the schema as text rather than as a parsed statement tree, the same trade the rest
/// of this file makes: a column named `owner_id` on a table named `orders` is read as indexed by
/// `create index ... on orders (owner_id, ...)`, by `owner_id ... primary key` or `... unique`
/// written inline on the column, or by a table-level `primary key (owner_id, ...)` or
/// `unique (owner_id, ...)`. A constraint added by a later `alter table` is not read at all: the
/// migrations under `deploy/db/migrations/` are concatenated with everything under `deploy/db/init/`,
/// so an index added there is still seen, but an `alter table ... add constraint` is a shape this
/// does not look for.
bool _isIndexed(String sql, String table, String column) {
  final String escapedTable = RegExp.escape(table);
  final String escapedColumn = RegExp.escape(column);

  final RegExp explicitIndex = RegExp(
    'create\\s+(?:unique\\s+)?index[^;]*\\bon\\s+(?:\\w+\\.)?"?$escapedTable"?\\s*\\(\\s*"?$escapedColumn"?\\b',
    caseSensitive: false,
  );
  if (explicitIndex.hasMatch(sql)) return true;

  final RegExp tableBlock = RegExp(
    'create\\s+table[^;(]*\\b(?:\\w+\\.)?"?$escapedTable"?\\s*\\(([\\s\\S]*?)\\)\\s*;',
    caseSensitive: false,
  );
  final RegExpMatch? block = tableBlock.firstMatch(sql);
  if (block == null) return false;

  final RegExp inlineConstraint = RegExp(
    '"?$escapedColumn"?\\s+[\\w\\s]*?\\b(?:primary\\s+key|unique)\\b'
    '|\\b(?:primary\\s+key|unique)\\s*\\(\\s*"?$escapedColumn"?\\b',
    caseSensitive: false,
  );
  return inlineConstraint.hasMatch(block.group(1) ?? '');
}

/// Every owned table `found` registers without an index on its owner column.
///
/// `registerTableOwners` fills a map read at every scoped query, and nothing in the framework
/// creates the index that map assumes. A table registered without one degrades from a lookup to
/// a full scan of the whole table the day it holds real rows, silently, since nothing fails
/// before then. Only `lib/` is read, never `tests/`: a registration in a fixture proves nothing
/// about what the package actually deploys.
List<Problem> _ownerIndexes(DiscoveredPackage found) {
  final Directory lib = globals.fs.directory(p.join(found.directory, 'lib'));
  if (!lib.existsSync()) return const <Problem>[];

  final Map<String, String> owners = <String, String>{};
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.ts')) {
      owners.addAll(_ownersDeclaredIn(entity.readAsStringSync()));
    }
  }
  if (owners.isEmpty) return const <Problem>[];

  final String sql = _sqlUnder(found.directory);

  return <Problem>[
    for (final MapEntry<String, String> owner in owners.entries)
      if (!_isIndexed(sql, owner.key, owner.value))
        Problem(
          found.name,
          'the table "${owner.key}" is registered with owner column "${owner.value}" through '
          'registerTableOwners, and nothing under deploy/db/ indexes that column. A scoped read '
          'reaches it on every call, so a table without the index degrades from a lookup to a full '
          'scan the day it holds real data.',
        ),
  ];
}
