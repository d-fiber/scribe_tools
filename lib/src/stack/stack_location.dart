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
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';

/// The environment variable that moves the whole stack cache elsewhere.
///
/// A test sets it to a temporary directory so that a run never touches the
/// machine's real cache, and an operator sets it when the home directory is not
/// where the cache belongs.
const String kStackHomeVariable = 'SCRIBE_STACK_HOME';

/// Where a project's assembled documents live, outside the project.
///
/// The project keeps what its own code imports and nothing else. What only
/// `docker compose` reads is written here, under a directory named after the
/// project's absolute path, so two clones of one project never share a file.
class StackLocation {
  /// Locates the cache of [project].
  StackLocation({Project? project}) : project = project ?? globals.project;

  /// The project whose documents this locates.
  final Project project;

  /// The root every project's cache sits under.
  ///
  /// `SCRIBE_STACK_HOME` wins when it is set. Otherwise the platform decides:
  /// `XDG_CACHE_HOME` when the environment names one, and `~/.cache` when it
  /// does not, which is also what Docker and most tools do on this machine.
  Directory get home {
    final Map<String, String> environment = globals.platform.environment;

    final String? named = environment[kStackHomeVariable];
    if (named != null && named.isNotEmpty) return globals.fs.directory(named);

    final String? xdg = environment['XDG_CACHE_HOME'];
    if (xdg != null && xdg.isNotEmpty) return globals.fs.directory(p.join(xdg, 'scribe'));

    final String home = environment['HOME'] ?? environment['USERPROFILE'] ?? '.';

    return globals.fs.directory(p.join(home, '.cache', 'scribe'));
  }

  /// The twelve hexadecimal characters that stand for this project's path.
  ///
  /// It is taken from the absolute path and not from the project's name,
  /// because the name is what two clones share and the path is what tells them
  /// apart. Twelve characters is what makes the directory readable at a glance
  /// while leaving a collision out of reach.
  String get fingerprint {
    final String absolute = p.canonicalize(project.directory.absolute.path);

    return sha256.convert(utf8.encode(absolute)).toString().substring(0, 12);
  }

  /// The directory this project's documents are written to.
  Directory get directory => home.childDirectory('stacks').childDirectory(fingerprint);

  /// The directory each service's own files are written to, one per service.
  Directory get services => directory.childDirectory('services');

  /// The directory the environment files a service reads are written to.
  Directory get env => directory.childDirectory('env');

  /// The file that says what was assembled, and how to drive it again.
  File get manifest => directory.childFile('stack.json');

  /// Empties and recreates [directory], and returns it.
  ///
  /// A render that kept what the previous one wrote would leave behind the
  /// overlay of a package the project has since dropped, and the only practical
  /// way to list the documents again is a glob, so the dead overlay would be
  /// mounted with the live ones.
  Directory prepare() {
    final Directory target = directory;
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);

    return target;
  }
}
