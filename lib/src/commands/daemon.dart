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

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/doctor/checkup.dart';
import 'package:scribe_tools/src/commands/doctor/report.dart';
import 'package:scribe_tools/src/commands/forge.dart';
import 'package:scribe_tools/src/commands/status.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';

/// Answers requests as JSON lines on standard input, one line of JSON back
/// per request, until told to stop.
///
/// An editor already has to parse `.scribe/resolution.json`; what this adds is
/// a process it can keep open instead of shelling out to `forge --machine`,
/// `status --machine` and `doctor --machine` on its own, one at a time, and
/// nothing to push a change back without being asked. `flutter daemon` fills
/// the same seat for an editor built on Flutter.
///
/// Every line in is `{"id": <any>, "method": "<name>", "params": {...}}`, and
/// every line out either answers one, `{"id": <the same id>, "result": {...}}`
/// or `{"id": ..., "error": "..."}`, or announces something on its own,
/// `{"event": "<name>", ...}`, with no `id` at all. Nothing else ever reaches
/// standard output: `checksVersion` is off, the same reasoning `completion`
/// carries, because a version notice printed into the middle of this stream
/// would be a line no reader could parse.
///
/// | Method | params | Answers |
/// | --- | --- | --- |
/// | `doctor` | none | [doctorMachineReport] |
/// | `forge` | none | [forgeProjectMachineReport] or [forgePackageMachineReport] |
/// | `status` | `target` | [statusMachineReport] |
/// | `watch.start` | none | `{"ok": true}`, then a `forge.changed` or `forge.failed` event per change |
/// | `watch.stop` | none | `{"ok": true}` |
/// | `shutdown` | none | `{"ok": true}`, then the process ends |
class DaemonCommand extends ScribeCommand {
  @override
  String get name => 'daemon';

  @override
  String get description => 'Answer requests as JSON lines on stdin, one line back per request, until told to stop.';

  @override
  bool get requiresProject => false;

  /// A request may need a machine this one is missing, and the daemon itself
  /// has to start regardless: the request that names what is missing is
  /// `doctor`, read the same way as everything else, not a report printed
  /// before the protocol even opens.
  @override
  bool get checksMachine => false;

  /// Nothing may reach standard output that is not a line of this protocol.
  @override
  bool get checksVersion => false;

  StreamSubscription<void>? _watching;
  bool _stopping = false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    printMachine(const <String, Object?>{'event': 'daemon.ready'});

    final Stream<String> lines = globals.stdio.stdin.transform(utf8.decoder).transform(const LineSplitter());

    await for (final String line in lines) {
      await _handle(line);
      if (_stopping) break;
    }

    await _stopWatch();

    return const ScribeCommandResult.success();
  }

  Future<void> _handle(String line) async {
    if (line.trim().isEmpty) return;

    Object? id;
    try {
      final Object? decoded = jsonDecode(line);
      if (decoded is! Map<String, Object?>) {
        throw const _DaemonError('a request is a JSON object, one per line.');
      }

      id = decoded['id'];
      final Object? method = decoded['method'];
      if (method is! String) throw const _DaemonError('a request needs a string "method".');

      if (method == 'shutdown') {
        _respond(id, result: const <String, Object?>{'ok': true});
        _stopping = true;
        return;
      }

      final Map<String, Object?> params = decoded['params'] as Map<String, Object?>? ?? const <String, Object?>{};
      _respond(id, result: await _dispatch(method, params));
    } on _DaemonError catch (error) {
      _respond(id, error: error.message);
    } on ToolExit catch (error) {
      _respond(id, error: error.message ?? 'failed');
    } on FormatException catch (error) {
      _respond(null, error: 'invalid JSON: ${error.message}');
    }
  }

  Future<Map<String, Object?>> _dispatch(String method, Map<String, Object?> params) async {
    switch (method) {
      case 'doctor':
        final List<DoctorSection> sections = await diagnose(assumeYes: false);
        return doctorMachineReport(sections, ok: sections.every((DoctorSection section) => section.isGood));

      case 'forge':
        return _forge();

      case 'status':
        final String? targetName = params['target'] as String?;
        if (targetName == null) throw const _DaemonError('status needs params.target.');
        return _status(targetName);

      case 'watch.start':
        _startWatch();
        return const <String, Object?>{'ok': true};

      case 'watch.stop':
        await _stopWatch();
        return const <String, Object?>{'ok': true};

      default:
        throw _DaemonError('Unknown method "$method".');
    }
  }

  Future<Map<String, Object?>> _forge() async {
    final Directory here = globals.fs.currentDirectory;

    if (Project.isProjectRoot(here)) {
      final ProjectForgeResult result = await forgeProject(project, quiet: true);

      return forgeProjectMachineReport(
        result.report,
        dryRun: false,
        lockFile: result.lockFile,
        scribeVersion: result.scribeVersion,
      );
    }

    if (here.childFile(kManifestFile).existsSync()) {
      final Sdk sdk = findSdk(from: here.path);
      return forgePackageMachineReport(sdk, resolve(here.path, sdk));
    }

    throw const _DaemonError(
      'forge runs at the root of a scribe project or of a package, and the daemon was started elsewhere.',
    );
  }

  Future<Map<String, Object?>> _status(String targetName) async {
    final ProjectConfiguration configuration = ProjectConfiguration.load(project: project);
    final Target target = configuration.target(targetName);
    final String? raw = await servicesOf(project, target);

    final List<ServiceStatus> services = raw == null
        ? const <ServiceStatus>[]
        : <ServiceStatus>[
            for (final String serviceLine in raw.trim().split('\n'))
              if (serviceLine.trim().isNotEmpty) ServiceStatus.parse(serviceLine),
          ];

    return statusMachineReport(configuration, target, services: services, ok: raw != null);
  }

  /// Watches `lib/` and the manifest the same way `forge --watch` does, and
  /// pushes a `forge.changed` event instead of printing a report: nobody
  /// asked for this one, so it cannot be an answer to a request.
  void _startWatch() {
    if (_watching != null) return;

    final Directory here = globals.fs.currentDirectory;
    final List<FileSystemEntity> entities = Project.isProjectRoot(here)
        ? <FileSystemEntity>[project.lib, project.config]
        : <FileSystemEntity>[here.childDirectory(kLibraryDirectory), here.childFile(kManifestFile)];

    _watching = globals.watcher.watch(entities).listen((void _) async {
      try {
        printMachine(<String, Object?>{'event': 'forge.changed', 'result': await _forge()});
      } on _DaemonError catch (error) {
        printMachine(<String, Object?>{'event': 'forge.failed', 'error': error.message});
      } on ToolExit catch (error) {
        printMachine(<String, Object?>{'event': 'forge.failed', 'error': error.message ?? 'failed'});
      }
    });
  }

  Future<void> _stopWatch() async {
    await _watching?.cancel();
    _watching = null;
  }

  void _respond(Object? id, {Object? result, String? error}) {
    printMachine(<String, Object?>{'id': id, 'result': ?result, 'error': ?error});
  }
}

/// What a request got refused for, before it ever became a [ToolExit].
class _DaemonError implements Exception {
  const _DaemonError(this.message);

  /// The sentence a caller reads in `"error"`.
  final String message;
}
