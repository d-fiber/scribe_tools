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

import 'package:crypto/crypto.dart';
import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/self/release_feed.dart';
import 'package:scribe_tools/src/self/tool_version.dart';
import 'package:scribe_tools/src/self/version.dart';

/// Where the tool's own binaries are published, the same repository `install.sh` reads.
const String kToolRepository = 'd-fiber/scribe_tools';

/// The name `install.sh` gives this platform's binary, null on one it never built for.
String? get _platformAsset {
  if (globals.platform.isWindows) return 'scribe_windows.exe';
  if (globals.platform.isMacOS) return 'scribe_macos';
  if (globals.platform.isLinux) return 'scribe_linux';
  return null;
}

/// The version this binary answers to, null on a build made without one.
///
/// A build through the Dart VM or compiled by hand carries `0.0.0`, which no
/// release publishes: comparing it against a real tag would always read as an
/// update waiting, so it is treated as nothing to compare at all.
Version? get installedToolVersion {
  final Version? version = Version.tryParse(kToolVersion);
  return version == const Version(0, 0, 0) ? null : version;
}

/// The version waiting in [kToolRepository]'s latest release, or null.
///
/// Reads the cache [scheduleToolFetch] keeps current; nothing here reaches
/// the network.
Version? pendingToolUpdate(Framework framework) {
  final Version? here = installedToolVersion;
  if (here == null) return null;

  final Version? there = versionOf(cachedLatestTag(_cacheFile(framework)));
  if (there == null) return null;

  return there.isNewerThan(here) ? there : null;
}

/// Starts a background check of [kToolRepository]'s latest release.
void scheduleToolFetch(Framework framework) =>
    scheduleTagFetch(kToolRepository, _cacheFile(framework), _marker(framework));

/// The version [kToolRepository] answers right now, a real network call.
///
/// Unlike [pendingToolUpdate], this is what `upgrade` calls: a person already
/// asked to wait, so the stale cache the passive notice reads is not good
/// enough here.
Future<Version?> latestToolVersion() async => versionOf(await fetchLatestTag(kToolRepository));

/// Replaces this platform's binary in [framework]'s `tools/` with the latest release.
///
/// Downloads next to the running binary and, when the release carries a
/// `scribe-checksums.txt`, verifies it against that the same way
/// `install.sh` does before renaming it into place. A release built before
/// that file existed is not treated as tampered with for lacking it: the
/// download proceeds on the size check alone, with a word about why. The
/// binary being replaced can be the one running this very command: a rename
/// over an open file is what every self-updating tool on Unix relies on, and
/// the closest a rename can come to it on Windows, which refuses to
/// overwrite one outright.
Future<void> applyToolUpdate(Framework framework) async {
  final String? asset = _platformAsset;
  if (asset == null) {
    throwToolExit('This platform has no scribe_tools binary published for it.');
  }

  final Directory tools = framework.root.childDirectory('tools');
  final File downloaded = tools.childFile('$asset.new');
  final String url = 'https://github.com/$kToolRepository/releases/latest/download/$asset';

  await _download(url, downloaded, name: asset);

  final File checksums = tools.childFile('scribe-checksums.txt.new');
  bool haveChecksums = true;
  try {
    await _download(
      'https://github.com/$kToolRepository/releases/latest/download/scribe-checksums.txt',
      checksums,
      name: 'scribe-checksums.txt',
    );
  } on ToolExit {
    haveChecksums = false;
    globals.logger.printWarning('This release carries no scribe-checksums.txt, so $asset was not verified.');
  }

  if (haveChecksums) {
    // A mismatch here is a real reason to stop: unlike the download above,
    // once the file exists, it is expected to agree with what it names.
    _verify(downloaded, checksums, asset);
    checksums.deleteSync();
  }

  final File target = tools.childFile(asset);
  final File backup = tools.childFile('$asset.old');
  if (backup.existsSync()) backup.deleteSync();
  if (target.existsSync()) target.renameSync(backup.path);
  downloaded.renameSync(target.path);
  if (backup.existsSync()) backup.deleteSync();

  if (!globals.platform.isWindows) {
    await globals.processRunner.run(commandArgv(Chmod.mode('+x').path(target.path)));
  }
}

Future<void> _download(String url, File target, {required String name}) async {
  if (target.existsSync()) target.deleteSync();

  if (globals.os.has('curl')) {
    final int code = await globals.processRunner.run(
      commandArgv(Curl.failFast().silent().showError().location().outputFile(target.path).url(url)),
    );
    if (code == 0 && target.existsSync() && target.lengthSync() > 0) return;
  } else if (globals.os.has('gh')) {
    final int code = await globals.processRunner.run(
      commandArgv(Gh.release().download().repo(kToolRepository).pattern(name).outputFile(target.path).clobber()),
    );
    if (code == 0 && target.existsSync() && target.lengthSync() > 0) return;
  } else {
    throwToolExit('Needs curl or the GitHub CLI to fetch $name.');
  }

  throwToolExit('Could not download $name from the latest release of $kToolRepository.');
}

void _verify(File downloaded, File checksums, String name) {
  String? want;
  for (final String line in checksums.readAsLinesSync()) {
    final List<String> fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length == 2 && fields[1] == name) {
      want = fields[0];
      break;
    }
  }
  if (want == null) throwToolExit('$name has no checksum in scribe-checksums.txt.');

  final String got = sha256.convert(downloaded.readAsBytesSync()).toString();
  if (got != want) {
    downloaded.deleteSync();
    throwToolExit('$name failed its checksum: expected $want, got $got.');
  }
}

File _cacheFile(Framework framework) => framework.root.childDirectory('.git').childFile('scribe-tool-latest.json');

File _marker(Framework framework) => framework.root.childDirectory('.git').childFile('scribe-tool-last-fetch');
