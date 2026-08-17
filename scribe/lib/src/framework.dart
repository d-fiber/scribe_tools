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
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/sdk_target.dart';
import 'package:scribe/src/version.dart';

/// The remote a checkout follows.
const String kOrigin = 'origin';

/// The branch people clone, and the only one a version is read from.
const String kReleaseBranch = 'main';

/// The checkout `upgrade` and `downgrade` act on.
///
/// Throws a [ToolExit] when there is none here, or when it is a copy rather
/// than a clone: a directory nobody cloned has no other version to move to.
Framework requireCheckout() {
  final Framework? framework = Framework.locate();

  if (framework == null) {
    throwToolExit(
      'No scribe checkout was found from here.\n'
      'This moves the framework a project is built on, so run it inside a checkout, '
      'or inside a project that carries one under scribe/.',
    );
  }

  if (!framework.isClone) {
    throwToolExit(
      'The checkout at ${framework.root.path} is not a git clone, so it has no versions to move between.\n'
      'Clone d-fiber/scribe instead of copying it.',
    );
  }

  return framework;
}

/// Refuses to move [framework] while it carries work that is not committed.
///
/// Throws a [ToolExit] naming what to do, since git would refuse a few steps
/// later with a message about the checkout rather than about scribe.
Future<void> requireCleanCheckout(Framework framework) async {
  if (await framework.isClean()) return;

  throwToolExit(
    'The checkout at ${framework.root.path} has changes that are not committed.\n'
    'Commit them, stash them, or drop them, then run this again.',
  );
}

/// One version of the framework, and the commit that wrote it.
class Release {
  const Release({required this.version, required this.commit, this.date});

  /// The version this commit put in `VERSION`.
  final Version version;

  /// The commit, in full.
  final String commit;

  /// When it was authored, null when the log did not say.
  final DateTime? date;

  /// The commit, as short as a human quotes it.
  String get shortCommit => commit.length <= 7 ? commit : commit.substring(0, 7);
}

/// The framework checkout a command is working against.
///
/// This is what carries a version. The tool itself does not: its binaries are
/// published from a rolling release and stay whatever build was installed, so
/// `upgrade` and `downgrade` move the checkout and leave the tool alone.
///
/// Every git call goes through the process runner, and none of them is a shell
/// line, so nothing here has to be escaped.
class Framework {
  const Framework(this.root);

  /// The checkout at or above [from], or null when there is none.
  ///
  /// The search is the one `create` already uses to find the SDKs, so a project
  /// that vendors the framework under `scribe/` is found too. A checkout
  /// without `VERSION` is not one: that file is the version.
  static Framework? locate({Directory? from}) {
    final Directory? found = SdkCatalog.findFrameworkRoot(from ?? globals.fs.currentDirectory);
    if (found == null) return null;

    final Framework framework = Framework(found);
    return framework.versionFile.existsSync() ? framework : null;
  }

  /// The root of the checkout.
  final Directory root;

  /// The file the version is written in.
  File get versionFile => root.childFile('VERSION');

  /// The version this checkout is on, null when `VERSION` says something else.
  Version? get version => Version.tryParse(versionFile.readAsStringSync());

  /// Whether this checkout is a git clone, and can therefore be moved.
  bool get isClone => root.childDirectory('.git').existsSync();

  /// The version `$kOrigin/$kReleaseBranch` is on, null when it cannot be read.
  ///
  /// Nothing is fetched here: it reads what the last fetch left behind, which
  /// is why it costs no network. [scheduleFetch] is what keeps it current.
  Future<Version?> versionOnOrigin() async {
    final String raw = await _capture(<String>['show', '$kOrigin/$kReleaseBranch:VERSION']);
    return raw.isEmpty ? null : Version.tryParse(raw);
  }

  /// Whether nothing is modified, added or removed in the checkout.
  Future<bool> isClean() async => (await _capture(<String>['status', '--porcelain'])).trim().isEmpty;

  /// The branch `HEAD` is on, empty when it is detached.
  Future<String> currentBranch() async => (await _capture(<String>['branch', '--show-current'])).trim();

  /// Every version this checkout's history knows, newest first.
  ///
  /// It is read from the log of `VERSION` itself rather than from tags: the
  /// repository has none, and `bump.py` writes that file on every release. One
  /// `git log -p` answers the whole list, so the cost does not grow with it.
  Future<List<Release>> history() async {
    final String log = await _capture(<String>[
      'log',
      '--format=$_commitMark%H %aI',
      '--patch',
      '--',
      'VERSION',
    ]);

    final List<Release> releases = <Release>[];
    String? commit;
    DateTime? date;

    for (final String line in log.split('\n')) {
      if (line.startsWith(_commitMark)) {
        final List<String> parts = line.substring(_commitMark.length).split(' ');
        commit = parts.first;
        date = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
        continue;
      }

      // The one added line of the diff is the version that commit introduced.
      if (!line.startsWith('+') || line.startsWith('+++')) continue;
      if (commit == null) continue;

      if (Version.tryParse(line.substring(1)) case final Version version) {
        releases.add(Release(version: version, commit: commit, date: date));
        commit = null;
      }
    }

    return releases;
  }

  /// Brings the remote's state in, and returns whether it worked.
  Future<bool> fetch() async => await _run(<String>['fetch', kOrigin, kReleaseBranch]) == 0;

  /// Moves `HEAD` onto the newest commit of the release branch.
  ///
  /// It never rewrites anything: a checkout that has diverged from the remote
  /// is left as it is and the merge refuses, which is what should happen to a
  /// checkout someone has been working in.
  Future<bool> fastForward() async {
    if (await currentBranch() != kReleaseBranch) {
      if (await _run(<String>['checkout', kReleaseBranch]) != 0) return false;
    }

    return await _run(<String>['merge', '--ff-only', '$kOrigin/$kReleaseBranch']) == 0;
  }

  /// Puts the checkout on [release], off any branch.
  ///
  /// A detached head is deliberate: an old version is somewhere to look at and
  /// build against, not somewhere to commit from, and `upgrade` brings the
  /// checkout back to the branch in one command.
  ///
  /// Git's own advice about that state is turned off for this call: it is
  /// fifteen lines about branches, printed above the two that say where the
  /// checkout now is and how to come back.
  Future<bool> checkout(Release release) async =>
      await _run(<String>['-c', 'advice.detachedHead=false', 'checkout', release.commit]) == 0;

  static const String _commitMark = 'commit ';

  Future<int> _run(List<String> arguments) =>
      globals.processRunner.run(<String>['git', ...arguments], workingDirectory: root.path);

  Future<String> _capture(List<String> arguments) =>
      globals.processRunner.capture(<String>['git', ...arguments], workingDirectory: root.path);
}
