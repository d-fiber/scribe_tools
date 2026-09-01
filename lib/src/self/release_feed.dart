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

import 'package:file/file.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/self/version.dart';

/// How long a cached "latest release" answer is trusted before refreshing it.
///
/// The same twelve hours `updates.dart` uses for the framework, and for the
/// same reason: a release is not news that has to reach a user within the
/// hour, and hitting GitHub on every command is what makes a tool feel slow.
const Duration kReleaseFetchInterval = Duration(hours: 12);

/// The tag GitHub answered for [repository]'s latest release, or null.
///
/// This is a real network call, and nothing here times it or retries it:
/// every caller either awaits it because a person is already waiting on
/// `scribe upgrade`, or does not call it at all and reads [cachedLatestTag]
/// instead. `curl` is tried first because it is what a machine is more likely
/// to already carry; `gh` answers the same field when there is no `curl`.
Future<String?> fetchLatestTag(String repository) async {
  final String url = 'https://api.github.com/repos/$repository/releases/latest';

  try {
    if (globals.os.has('curl')) {
      final String body = await globals.processRunner.capture(<String>['curl', '-fsSL', url]);
      return _tagIn(body);
    }

    if (globals.os.has('gh')) {
      return (await globals.processRunner.capture(<String>[
        'gh',
        'api',
        'repos/$repository/releases/latest',
        '-q',
        '.tag_name',
      ])).trim();
    }
  } catch (error) {
    globals.logger.printTrace('[release_feed] $error');
  }

  return null;
}

/// [tag], read as a version once its leading `v` is dropped, or null.
Version? versionOf(String? tag) => tag == null ? null : Version.tryParse(tag.startsWith('v') ? tag.substring(1) : tag);

/// The tag a previous [scheduleTagFetch] wrote to [cacheFile], or null.
///
/// Nothing is fetched here: this is the local, instant half of the pair that
/// [pendingUpdate](in `updates.dart`) is built on for the framework, ported to
/// a repository whose releases live on GitHub rather than on a branch this
/// checkout can `git fetch`.
String? cachedLatestTag(File cacheFile) {
  if (!cacheFile.existsSync()) return null;

  try {
    final Object? document = jsonDecode(cacheFile.readAsStringSync());
    return document is Map && document['tag_name'] is String ? document['tag_name'] as String : null;
  } catch (error) {
    globals.logger.printTrace('[release_feed] $error');
    return null;
  }
}

/// Starts a background fetch of [repository]'s latest release into [cacheFile], gated by [marker].
///
/// The marker is touched before the fetch starts and not after, the same
/// trade `updates.dart` makes for the framework: two commands run back to
/// back must not both start one, and a fetch that fails costs a silent half
/// day rather than a retry nobody asked for. Skipped without a word when
/// `curl` is not on `PATH`: `gh api` writes only to its own stdout, which a
/// detached process has nowhere to send but a shell redirection this runner
/// deliberately never opens, so it cannot stand in for `curl` here the way it
/// does for [fetchLatestTag].
void scheduleTagFetch(String repository, File cacheFile, File marker) {
  if (marker.existsSync() && DateTime.now().difference(marker.lastModifiedSync()) < kReleaseFetchInterval) return;

  marker.parent.createSync(recursive: true);
  marker.writeAsStringSync('');

  if (!globals.os.has('curl')) return;

  final String url = 'https://api.github.com/repos/$repository/releases/latest';
  globals.processRunner.detach(<String>['curl', '-fsSL', '-o', cacheFile.path, url]);
}

String? _tagIn(String body) {
  final Object? document = jsonDecode(body);
  return document is Map && document['tag_name'] is String ? document['tag_name'] as String : null;
}
