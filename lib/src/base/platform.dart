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
  /// Holds nothing, so every implementation can be a constant.
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

  /// The path of the executable this process is, symbolic links unresolved.
  ///
  /// It is what says where the tool itself sits, which is how a command reaches
  /// the checkout that installed it when the current directory is nowhere near
  /// one.
  String get resolvedExecutable;

  /// The entrypoint this process was started from.
  ///
  /// Its scheme says how the tool was started, which is the only thing that
  /// tells a compiled binary apart from a `dart run` of `bin/scribe.dart`: a
  /// binary answers its own path, a source run answers the entrypoint under
  /// `bin/`, and a test answers a `data:` URI. That is what
  /// `defaultToolRoot` reads to find the directory the templates sit in.
  Uri get script;

  /// The `package_config.json` this process resolves its imports through, when it has one.
  ///
  /// Null for a compiled binary, which resolved everything at build time.
  String? get packageConfig;

  /// Whether this platform is Windows.
  bool get isWindows => operatingSystem == 'windows';

  /// Whether this platform is macOS.
  bool get isMacOS => operatingSystem == 'macos';

  /// Whether this platform is Linux.
  bool get isLinux => operatingSystem == 'linux';
}

/// The [Platform] that answers from `dart:io`.
class LocalPlatform extends Platform {
  /// Answers from the process this code runs in.
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

  @override
  String get resolvedExecutable => io.Platform.resolvedExecutable;

  @override
  Uri get script => io.Platform.script;

  @override
  String? get packageConfig => io.Platform.packageConfig;
}

/// A [Platform] whose answers are fixed by its constructor.
class FakePlatform extends Platform {
  /// Answers whatever it is handed, and reads nothing of the real system.
  const FakePlatform({
    this.operatingSystem = 'macos',
    this.environment = const <String, String>{},
    this.pathSeparator = '/',
    this.stdoutSupportsAnsi = false,
    this.version = 'test',
    this.resolvedExecutable = '/usr/bin/scribe',
    this.scriptPath = _testEntrypoint,
    this.packageConfig,
  });

  /// The entrypoint a test run reports, which is the source it was compiled from.
  static const String _testEntrypoint = 'data:application/dart;charset=utf-8,';

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

  @override
  final String resolvedExecutable;

  /// What [script] is parsed from, spelled as a URI so a test can name a scheme.
  ///
  /// It is a string rather than a [Uri] because this class is a constant and
  /// there is no constant way to build a [Uri]. A test naming a file passes
  /// `file:///path`, since a bare path parses to no scheme at all.
  final String scriptPath;

  @override
  final String? packageConfig;

  @override
  Uri get script => Uri.parse(scriptPath);
}
