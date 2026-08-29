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

import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/package/constraint.dart';
import 'package:scribe_tools/src/package/declares.dart';
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
/// What a package needs to run its own suite is held to the same rule as what it
/// depends on: it names a package or it names nothing, and a suite written
/// against a package nobody wrote fails the same way a consumer would.
///
/// An entry written [kAny] is skipped, because it names a specifier the checkout
/// pins rather than a package. Looking one up here would report every redis
/// client a package plainly imports as a package nobody wrote.
List<Problem> _dependencies(DiscoveredPackage found, Map<String, DiscoveredPackage> known) {
  final List<Problem> problems = <Problem>[];
  final Map<String, String> asked = <String, String>{...found.manifest.dependencies, ...found.manifest.devDependencies};

  for (final MapEntry<String, String> entry in asked.entries) {
    if (entry.value == kAny) continue;

    final DiscoveredPackage? target = known[entry.key];
    if (target == null) {
      problems.add(Problem(found.name, 'it depends on "${entry.key}", and no package of that name exists.'));
      continue;
    }

    if (allows(entry.value, target.manifest.version)) continue;
    problems.add(
      Problem(
        found.name,
        'it depends on "${entry.key}" ${entry.value}, and the copy on hand is ${target.manifest.version}.',
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
