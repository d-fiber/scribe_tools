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
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/self/version.dart';

/// How long the last fetch is trusted before another one is worth starting.
///
/// Twelve hours is what `flutter` settled on, and the reasoning holds here: a
/// release is not something a user needs to hear about within the hour, and
/// hitting the network on every command to say the same thing is what makes a
/// tool feel slow.
const Duration kFetchInterval = Duration(hours: 12);

/// The file whose date says when a fetch was last started.
///
/// It sits in `.git/` because that is where a checkout keeps what is about the
/// clone and not about the code, and because it is never committed from there.
/// Its date is all that is read; nothing is written inside it.
const String kFetchMarker = 'scribe-last-fetch';

/// The version waiting on the release branch, or null when there is none.
///
/// Nothing is fetched: this reads what the last fetch brought in, so it costs
/// one local git call. [scheduleFetch] is what keeps that state current.
Future<Version?> pendingUpdate(Framework framework) async {
  final Version? here = framework.version;
  if (here == null) return null;

  final Version? there = await framework.versionOnOrigin();
  if (there == null) return null;

  return there.isNewerThan(here) ? there : null;
}

/// Says that a newer framework is out, and starts the fetch for the next run.
///
/// This is what every command ends with. It is informational and nothing waits
/// on it: the fetch is detached, so the command the user typed is already done
/// when it starts, and its result is only read on some later run.
///
/// Anything that goes wrong here is traced and dropped. A version check is
/// never a reason for a command that worked to look like it failed.
Future<void> announceUpdate() async {
  try {
    final Framework? framework = Framework.locate();
    if (framework == null || !framework.isClone) return;

    if (await pendingUpdate(framework) case final Version newer) {
      globals.logger.printStatus('');
      globals.logger.printStatus(
        'A new version of scribe is available: $newer, and this checkout is on ${framework.version}.',
        emphasis: true,
      );
      globals.logger.printStatus('Run `scribe upgrade` to get it.');
    }

    scheduleFetch(framework);
  } catch (error) {
    globals.logger.printTrace('[updates] $error');
  }
}

/// Starts a fetch in the background when the last one is old enough.
///
/// The marker is touched before the fetch and not after, so two commands run
/// back to back do not both start one. A fetch that fails therefore costs a
/// silent half-day, which is the right trade for a check nobody asked for.
void scheduleFetch(Framework framework) {
  final File marker = framework.root.childDirectory('.git').childFile(kFetchMarker);

  if (marker.existsSync() && DateTime.now().difference(marker.lastModifiedSync()) < kFetchInterval) return;

  marker.writeAsStringSync('');
  globals.processRunner.detach(<String>['git', '-C', framework.root.path, 'fetch', '--quiet', kOrigin, kReleaseBranch]);
}
