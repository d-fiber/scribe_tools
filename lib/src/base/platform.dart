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

import 'dart:io' as io;

/// The host system, behind something a test can replace.
abstract class Platform {
  const Platform();

  /// The system this runs on, named as `dart:io` names it: `macos`, `linux`, `windows`.
  String get operatingSystem;

  /// The environment this process was started with.
  Map<String, String> get environment;

  /// The character that separates the segments of a path.
  String get pathSeparator;

  /// Whether standard output understands ANSI escape sequences.
  bool get stdoutSupportsAnsi;

  /// The Dart version string, which also names the architecture at its end.
  String get version;

  bool get isWindows => operatingSystem == 'windows';

  bool get isMacOS => operatingSystem == 'macos';

  bool get isLinux => operatingSystem == 'linux';
}

/// The [Platform] that answers from `dart:io`.
class LocalPlatform extends Platform {
  const LocalPlatform();

  @override
  String get operatingSystem => io.Platform.operatingSystem;

  @override
  Map<String, String> get environment => io.Platform.environment;

  @override
  String get pathSeparator => io.Platform.pathSeparator;

  @override
  bool get stdoutSupportsAnsi => io.stdout.supportsAnsiEscapes;

  @override
  String get version => io.Platform.version;
}

/// A [Platform] whose answers are fixed by its constructor.
class FakePlatform extends Platform {
  const FakePlatform({
    this.operatingSystem = 'macos',
    this.environment = const <String, String>{},
    this.pathSeparator = '/',
    this.stdoutSupportsAnsi = false,
    this.version = 'test',
  });

  @override
  final String operatingSystem;

  @override
  final Map<String, String> environment;

  @override
  final String pathSeparator;

  @override
  final bool stdoutSupportsAnsi;

  @override
  final String version;
}
