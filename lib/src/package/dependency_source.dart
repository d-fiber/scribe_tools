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

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// One way `package.yaml` may say where a dependency comes from.
sealed class DependencySource {}

/// One way `config.yaml` may say where a package this project mounts comes from.
sealed class ProjectDependencySource {}

/// A dependency held to a version constraint, resolved beside the package that
/// asked for it or under the checkout's own `packages/`, the way it always was.
///
/// The name matches what a `pubspec.yaml` calls the same idea, `sdk: flutter`
/// for a package the Flutter SDK ships: nothing is fetched for either, since
/// what is named already sits inside the checkout, so nothing here is ever
/// cached the way [GitSource] is.
final class SdkSource implements DependencySource {
  /// Records the [constraint] the manifest wrote.
  const SdkSource(this.constraint);

  /// The constraint, as the manifest wrote it: a caret, an exact version, or `any`.
  final String constraint;
}

/// A package `config.yaml` mounts from the checkout: a bare name, or `sdk:` saying
/// the same thing out loud.
final class CheckoutSource implements ProjectDependencySource {
  /// Holds nothing: the checkout is the one place a name without a source answers to.
  const CheckoutSource();
}

/// A dependency read from a local copy, at [path] relative to whatever wrote it.
final class PathSource implements DependencySource, ProjectDependencySource {
  /// Records the [path] the manifest wrote.
  const PathSource(this.path);

  /// The path, as the manifest wrote it, unresolved.
  final String path;
}

/// A dependency read out of a git repository.
///
/// [ref] names a branch, a tag or a commit; left out, the remote's own default
/// branch is resolved and followed. [path] names the subdirectory of the
/// repository the dependency actually lives in, left out for a repository
/// whose root is the dependency itself.
final class GitSource implements DependencySource, ProjectDependencySource {
  /// Records the [url], and the [ref] and [path] the manifest gave it, if any.
  const GitSource({required this.url, this.ref, this.path});

  /// The address `git` clones from.
  final String url;

  /// The branch, tag or commit to check out, or null for the remote's default branch.
  final String? ref;

  /// The subdirectory of the repository the dependency lives in, or null for its root.
  final String? path;
}

/// The variable that names where every package this tool fetches is cached,
/// the way `PUB_CACHE` does for pub.
const String kCacheVariable = 'SCRIBE_CACHE';

/// Where this machine keeps every package the tool has fetched: one cache, the
/// way `~/.pub-cache` is pub's one, rather than a directory guessed anew by
/// each kind of dependency that needs to cache something.
///
/// [kCacheVariable] overrides it. Unset, it is `~/.scribe-cache` on Linux and
/// macOS, and `%LOCALAPPDATA%\Scribe\Cache` on Windows, the same split pub
/// itself makes between the two.
///
/// Throws a [ToolExit] when neither [kCacheVariable] nor a home directory the
/// default can be built from is set.
Directory scribeCacheRoot() {
  final Map<String, String> environment = globals.platform.environment;
  final String? explicit = environment[kCacheVariable];
  if (explicit != null && explicit.isNotEmpty) return globals.fs.directory(explicit);

  if (globals.platform.isWindows) {
    final String? local = environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) {
      throwToolExit('Neither $kCacheVariable nor LOCALAPPDATA is set, so there is nowhere to cache a package.');
    }
    return globals.fs.directory(p.join(local, 'Scribe', 'Cache'));
  }

  final String? home = environment['HOME'];
  if (home == null || home.isEmpty) {
    throwToolExit('Neither $kCacheVariable nor HOME is set, so there is nowhere to cache a package.');
  }
  return globals.fs.directory(p.join(home, '.scribe-cache'));
}

/// Every git dependency's clones, under [scribeCacheRoot], mirroring the shape
/// of pub's own `$PUB_CACHE/git/`: a bare mirror per repository under
/// `cache/`, and a working copy per commit resolved from one, directly under it.
Directory gitCacheRoot() => scribeCacheRoot().childDirectory('git');

/// Ensures [name]'s git dependency, [source], has a mirror and a working copy
/// of the commit it resolves to, and answers the directory to read the
/// dependency from, together with that commit.
///
/// [GitSource.path] is applied under the working copy; left null, the working
/// copy itself is the answer. [where] names the dependency in whatever this
/// throws.
///
/// The mirror is a bare `git clone --mirror`, made once and fetched on every
/// call after, so a floating ref, a branch or the remote's default branch
/// taken because [GitSource.ref] named none, is never served stale. The
/// working copy is named after the exact commit it holds and is never touched
/// again once it exists, the same way pub's own `git/<name>-<hash>/` is: two
/// dependents that resolve to the same commit share it, and two that resolve
/// to different commits never fight over one directory.
///
/// Throws a [ToolExit] when `git` fails at any step.
(Directory, String) resolveGit(String name, GitSource source, {required String where}) {
  final Directory mirror = gitCacheRoot().childDirectory('cache').childDirectory('$name-${_hash(source.url)}');

  if (!mirror.existsSync()) {
    mirror.parent.createSync(recursive: true);
    _run(Git.clone().arg('--mirror').arg(source.url).arg(mirror.path), where: where, doing: 'clone ${source.url}');
  } else {
    _run(
      Git.fetch().pruneFlag().remoteName('origin'),
      workingDirectory: mirror.path,
      where: where,
      doing: 'fetch ${source.url}',
    );
  }

  final String ref = source.ref ?? _defaultBranchOf(mirror, where: where);
  final String commit = _run(
    Git.revParse().arg('$ref^{commit}'),
    workingDirectory: mirror.path,
    where: where,
    doing: 'resolve "$ref" of ${source.url}',
  ).trim();

  final Directory workingCopy = gitCacheRoot().childDirectory('$name-$commit');
  if (!workingCopy.existsSync()) {
    _run(Git.clone().arg(mirror.path).arg(workingCopy.path), where: where, doing: 'check out ${source.url} at $commit');
    _run(
      Git.checkout().arg(commit),
      workingDirectory: workingCopy.path,
      where: where,
      doing: 'check out ${source.url} at $commit',
    );
  }

  final Directory directory = source.path == null ? workingCopy : workingCopy.childDirectory(source.path!);
  return (directory, commit);
}

/// The default branch [mirror] itself resolves to, read off its own `HEAD`.
///
/// A `--mirror` clone points its own `HEAD` at the remote's default branch the
/// moment it is made, so this reads what cloning or fetching already resolved
/// rather than asking the remote a second time.
String _defaultBranchOf(Directory mirror, {required String where}) {
  final String branch = _run(
    Git.symbolicRef().short().arg('HEAD'),
    workingDirectory: mirror.path,
    where: where,
    doing: 'read the default branch of its repository',
  ).trim();

  if (branch.isEmpty) {
    throwToolExit('$where names no ref, and the default branch of its repository could not be read.');
  }

  return branch;
}

/// Runs [command], answering what it wrote on standard output.
///
/// Throws a [ToolExit] naming [where] and [doing] when it fails, with whatever
/// `git` itself wrote on standard error.
String _run(GitCmd command, {String? workingDirectory, required String where, required String doing}) {
  final ProcessOutcome outcome = globals.processRunner.observeSync(
    commandArgv(command),
    workingDirectory: workingDirectory,
  );
  if (!outcome.succeeded) {
    throwToolExit('$where: git could not $doing.\n${outcome.stderr.trim()}');
  }

  return outcome.stdout;
}

/// The key a repository at [url] is cached under, one per distinct URL.
///
/// A hash rather than the URL itself sanitised, because sanitising still
/// collides two URLs that only differ in the punctuation it strips.
String _hash(String url) => sha256.convert(utf8.encode(url)).toString();
