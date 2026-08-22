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

import 'package:scribe_tools/src/commands/doctor/report.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/tools.dart';

/// What this machine is, and what it can install with.
///
/// Nothing here can fail: the machine is whatever it is. It is reported because
/// it is the first thing anyone reading a bug report wants to know, and because
/// [manager] decides what `--rescue` is able to do.
DoctorSection machineSection(PackageManager? manager) {
  final String installer = manager == null ? 'no package manager' : '${manager.name} available';

  return DoctorSection(
    title: 'Machine',
    summary: '${globals.os.hostPlatform}, ${globals.shell.name}, $installer',
    findings: <Finding>[
      Finding.ok('${globals.os.hostPlatform}'),
      Finding.ok(globals.shell.name),
      if (manager == null)
        const Finding.note(
          'no package manager found',
          hint:
              'Install one of homebrew, winget, scoop, apt, dnf, pacman or apk, and --rescue '
              'will be able to install what is missing.',
        )
      else
        Finding.ok('${manager.name} available'),
    ],
  );
}
