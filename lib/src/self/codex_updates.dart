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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/self/gh_cmd.dart';
import 'package:scribe_tools/src/self/release_feed.dart';
import 'package:scribe_tools/src/self/version.dart';

/// Where the dashboard is published, the same repository `install.sh` reads.
const String kCodexRepository = 'd-fiber/scribe_codex';

/// The asset `publish.yml` attaches to a `scribe_codex` release.
const String kCodexAsset = 'scribe-codex.tar.gz';

/// The version of the dashboard installed under [framework], null when there is none.
///
/// Read from `version.json`, which `flutter build web` writes into the site
/// itself: the same file names the version whether it got here through
/// `install.sh` or through [applyCodexUpdate].
Version? installedCodexVersion(Framework framework) {
  final File versionFile = framework.root.childDirectory('web').childDirectory('codex').childFile('version.json');
  if (!versionFile.existsSync()) return null;

  try {
    final Object? document = jsonDecode(versionFile.readAsStringSync());
    return document is Map && document['version'] is String ? Version.tryParse(document['version'] as String) : null;
  } catch (error) {
    globals.logger.printTrace('[codex_updates] $error');
    return null;
  }
}

/// The version waiting in [kCodexRepository]'s latest release, when it is
/// newer than what is installed, or when nothing is installed at all.
///
/// Reads the cache [scheduleCodexFetch] keeps current; nothing here reaches
/// the network.
Version? pendingCodexUpdate(Framework framework) {
  final Version? there = versionOf(cachedLatestTag(_cacheFile(framework)));
  if (there == null) return null;

  final Version? here = installedCodexVersion(framework);
  if (here != null && !there.isNewerThan(here)) return null;

  return there;
}

/// Starts a background check of [kCodexRepository]'s latest release.
void scheduleCodexFetch(Framework framework) =>
    scheduleTagFetch(kCodexRepository, _cacheFile(framework), _marker(framework));

/// The version [kCodexRepository] answers right now, a real network call.
///
/// Unlike [pendingCodexUpdate], this is what `upgrade` calls: a person
/// already asked to wait, so the stale cache the passive notice reads is not
/// good enough here.
Future<Version?> latestCodexVersion() async => versionOf(await fetchLatestTag(kCodexRepository));

/// Replaces `web/codex/` under [framework] with the latest release's build.
///
/// Degrades to doing nothing, loudly, when no release carries the asset yet:
/// `scribe_codex` is younger than the rest of the framework and does not
/// always have one, the same case `install.sh` accepts without failing.
Future<void> applyCodexUpdate(Framework framework) async {
  final Directory web = framework.root.childDirectory('web');
  final File archive = web.childFile(kCodexAsset);
  const String url = 'https://github.com/$kCodexRepository/releases/latest/download/$kCodexAsset';

  web.createSync(recursive: true);
  if (archive.existsSync()) archive.deleteSync();

  if (globals.os.has('curl')) {
    final int code = await globals.processRunner.run(
      commandArgv(Curl.failFast().silent().showError().location().outputFile(archive.path).url(url)),
    );
    if (code != 0) throwToolExit('No release of $kCodexRepository carries $kCodexAsset yet.');
  } else if (globals.os.has('gh')) {
    final int code = await globals.processRunner.run(
      commandArgv(
        Gh.release().download().repo(kCodexRepository).pattern(kCodexAsset).outputFile(archive.path).clobber(),
      ),
    );
    if (code != 0) throwToolExit('No release of $kCodexRepository carries $kCodexAsset yet.');
  } else {
    throwToolExit('Needs curl or the GitHub CLI to fetch $kCodexAsset.');
  }

  if (!archive.existsSync() || archive.lengthSync() == 0) {
    throwToolExit('$kCodexAsset came down empty.');
  }

  final Directory codex = web.childDirectory('codex');
  if (codex.existsSync()) codex.deleteSync(recursive: true);

  final int extracted = await globals.processRunner.run(
    commandArgv(Tar.extract().gzip().file(archive.path).changeDirectory(web.path)),
  );
  archive.deleteSync();
  if (extracted != 0 || !codex.childFile('index.html').existsSync()) {
    throwToolExit('$kCodexAsset carried no codex/index.html.');
  }
}

File _cacheFile(Framework framework) => framework.root.childDirectory('.git').childFile('scribe-codex-latest.json');

File _marker(Framework framework) => framework.root.childDirectory('.git').childFile('scribe-codex-last-fetch');
