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
import 'package:scribe_tools/src/framework.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/version.dart';

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
        'A new version of scribe is available: ${framework.version} → $newer',
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
  globals.processRunner.detach(<String>[
    'git',
    '-C',
    framework.root.path,
    'fetch',
    '--quiet',
    kOrigin,
    kReleaseBranch,
  ]);
}
