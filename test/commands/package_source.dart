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

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/runner.dart' as runner;
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/base/watch.dart';
import 'package:scribe_tools/src/commands/analyze.dart';
import 'package:scribe_tools/src/commands/clean.dart';
import 'package:scribe_tools/src/commands/create.dart';
import 'package:scribe_tools/src/commands/editor.dart';
import 'package:scribe_tools/src/commands/forge.dart';
import 'package:scribe_tools/src/commands/test.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/templates.dart';

/// The directory a package is written into by the tests below.
const String kWorkDirectory = '/work';

/// The checkout every test resolves against, named by `SCRIBE_ROOT`.
const String kCheckoutDirectory = '/framework';

/// The home directory the resolution builds the runtime's files under.
const String kHomeDirectory = '/home/someone';

/// Where the executables this fake machine carries are written.
const String kBinDirectory = '/usr/bin';

/// The root the templates are vendored under, standing in for an installed tool.
const String kToolRootDirectory = '/tools';

/// The file system, the buffer and the runner a test reads back what happened from.
///
/// Nothing here reaches the disk, the terminal or a process. It matters more than
/// convenience: a resolution writes under the home directory, so a suite let
/// through to the real one would write into the directory of whoever ran it and
/// read back whatever was already there.
class PackageHarness {
  /// Opens a machine carrying every tool a command looks for, and a checkout at [kCheckoutDirectory].
  PackageHarness() {
    for (final String executable in <String>['git', 'deno', 'npm', 'docker', 'tofu', 'ssh', 'rsync']) {
      fs.file('$kBinDirectory/$executable').createSync(recursive: true);
    }

    fs.currentDirectory = fs.directory(kWorkDirectory)..createSync(recursive: true);
    writeCheckout();
    _vendorTemplates();
  }

  /// The file system everything this run reads and writes lives in.
  final MemoryFileSystem fs = MemoryFileSystem.test();

  /// What the commands printed.
  final BufferLogger logger = BufferLogger();

  /// What the commands asked to be run, none of which was started.
  final RecordingProcessRunner processRunner = RecordingProcessRunner();

  /// What a `--watch` command reruns against, driven by hand instead of a real directory.
  final FakeWatcher watcher = FakeWatcher();

  /// Writes a checkout at [kCheckoutDirectory] publishing [version].
  ///
  /// It carries the three directories a checkout is recognised by, the tracked
  /// `scribe.workspace.json` the version is read from, and the import map that says what it
  /// carries: the language, the framework's own directories, and every version outside it. No
  /// `deno.json` is written, the same as a bare clone.
  void writeCheckout({String version = '3.0.1'}) {
    for (final String directory in <String>['sdk', 'engine', 'protocol']) {
      fs.directory('$kCheckoutDirectory/$directory').createSync(recursive: true);
    }

    fs.file('$kCheckoutDirectory/$kSdkWorkspaceFile')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"version":"$version","imports":{"@scribe/alchemy":"./engine/alchemy/mod.ts",'
        '"@scribe/contracts/":"./engine/contracts/"}}\n',
      );

    fs.file('$kCheckoutDirectory/engine/alchemy/mod.ts')
      ..createSync(recursive: true)
      ..writeAsStringSync('export {};\n');
  }

  /// Copies the templates that ship into [fs], under [kToolRootDirectory].
  ///
  /// The ones on disk rather than a fixture, so that a template edited in this
  /// package moves these tests: what `scribe create --package` writes is exactly
  /// what a user gets.
  void _vendorTemplates() {
    const String source = 'templates/package';

    for (final io.FileSystemEntity entity in io.Directory(source).listSync(recursive: true)) {
      if (entity is! io.File) continue;

      final String relative = p.relative(entity.path, from: source);
      fs.file(p.join(kToolRootDirectory, 'templates/package', relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(entity.readAsStringSync());
    }
  }

  /// Runs `scribe` with [args] against this machine, and answers the status it left with.
  Future<int> run(List<String> args) => runner.run(
    args,
    () => <ScribeCommand>[
      AnalyzeCommand(),
      CleanCommand(),
      CreateCommand(),
      EditorCommand(),
      ForgeCommand(),
      TestCommand(),
    ],
    toolVersion: 'test',
    overrides: <Type, Generator>{
      FileSystem: () => fs,
      Logger: () => logger,
      Stdio: FakeStdio.new,
      ProcessRunner: () => processRunner,
      Watcher: () => watcher,
      TemplatePathProvider: () => FixedTemplatePathProvider(fs.directory(kToolRootDirectory)),
      Platform: () => const FakePlatform(
        environment: <String, String>{
          'PATH': kBinDirectory,
          'HOME': kHomeDirectory,
          kSdkRootVariable: kCheckoutDirectory,
        },
      ),
    },
  );
}
