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
import 'package:scribe_tools/src/base/common.dart';

/// What an assembly produced, written next to the documents it produced.
///
/// Without it a second run has to guess three things the first one knew: which
/// documents to pass Compose and in what order, which profiles to switch on,
/// and which directory the relative paths inside those documents are written
/// against. Guessing the order from a glob is what mounts the overlay of a
/// package the project has dropped.
class StackManifest {
  /// Records an assembly.
  const StackManifest({
    required this.projectDirectory,
    required this.projectName,
    required this.files,
    required this.profiles,
  });

  /// Reads back what [file] recorded.
  ///
  /// Throws a [ToolExit] when the file is absent or does not parse, since a
  /// caller reaching for it is about to drive a stack it cannot describe.
  factory StackManifest.read(File file) {
    if (!file.existsSync()) {
      throwToolExit('This project is not running. Start it with `scribe run`.');
    }

    try {
      final Map<String, Object?> json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

      return StackManifest(
        projectDirectory: json['projectDirectory']! as String,
        projectName: json['projectName']! as String,
        files: <String>[for (final Object? entry in json['files']! as List<Object?>) entry! as String],
        profiles: <String>[for (final Object? entry in json['profiles']! as List<Object?>) entry! as String],
      );
    } on Object {
      throwToolExit('What `scribe run` recorded at ${file.path} does not read. Run it again.');
    }
  }

  /// The absolute path every relative path in the documents is resolved against.
  ///
  /// It is the project root and not the directory holding the documents, which
  /// is why every invocation carries `--project-directory`.
  final String projectDirectory;

  /// The name Docker knows this stack by, which comes from `config.yaml`.
  ///
  /// It follows the project rather than its directory, so a project that moves
  /// is still stopped by the name it was started under.
  final String projectName;

  /// The documents to pass Compose in `-f`, in the order it must read them.
  final List<String> files;

  /// The Compose profiles to switch on, sorted.
  final List<String> profiles;

  /// Writes this record to [file].
  void write(File file) {
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'projectDirectory': projectDirectory, 'projectName': projectName, 'files': files, 'profiles': profiles})}\n',
    );
  }

  /// The arguments that name this stack to Compose, before any verb.
  ///
  /// A caller writes `docker compose ${arguments} up -d` and never assembles
  /// the flags itself, because leaving out `--project-directory` resolves every
  /// relative path against the wrong root and leaving out `-p` drives whatever
  /// stack the current directory happens to name.
  List<String> get arguments => <String>[
    '--project-directory',
    projectDirectory,
    '-p',
    projectName,
    for (final String file in files) ...<String>['-f', file],
    for (final String profile in profiles) ...<String>['--profile', profile],
  ];
}
