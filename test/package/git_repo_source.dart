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

import 'dart:io';

/// Turns everything already written under [root] into a git repository on
/// [branch], committing it all in one commit, and answers that commit.
///
/// `git` itself runs rather than being faked: a git dependency is resolved by
/// shelling out to it, and a fake would only prove that the fake agrees with
/// itself. The repository never leaves the local disk, so nothing here reaches
/// a real network.
String initGitRepo(String root, {String branch = 'trunk'}) {
  _git(root, <String>['init', '--quiet', '--initial-branch=$branch']);
  _git(root, <String>['config', 'user.email', 'test@example.com']);
  _git(root, <String>['config', 'user.name', 'Scribe Test']);
  _git(root, <String>['add', '.']);
  _git(root, <String>['commit', '--quiet', '-m', 'initial']);

  return _git(root, <String>['rev-parse', 'HEAD']).trim();
}

String _git(String root, List<String> arguments) {
  final ProcessResult result = Process.runSync('git', arguments, workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed in $root: ${result.stderr}');
  }

  return '${result.stdout}';
}
