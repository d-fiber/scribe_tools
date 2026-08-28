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
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/stack/stack_location.dart';

/// The file a rendered recipe is written to.
///
/// OpenTofu reads `.tf.json` exactly as it reads `.tf`, and the JSON syntax
/// exists for configuration produced by a program: Dart has no HCL library, so
/// this is the door, and it is the one the documentation points at.
const String tofuConfigurationName = 'main.tf.json';

/// The binary this shells out to.
const String tofuBinary = 'tofu';

/// The directory the providers are kept in, shared by every workspace.
///
/// Without it each resource downloads its own copy of every provider it names,
/// which on a slow line is the whole of a deployment's time. It is a cache in
/// the plain sense: deleting it costs a download and nothing else.
const String pluginCacheDirectoryName = 'tofu-plugins';

/// One run of OpenTofu against one workspace.
///
/// It shells out rather than speaking any protocol, because what it buys is the
/// provider registry, the dependency graph, the plan and the state, and all four
/// live in the binary.
class Tofu {
  /// Works in [workspace], calling [binary].
  const Tofu(this.workspace, {this.binary = tofuBinary});

  /// The directory holding the configuration, the state and the lock.
  final Directory workspace;

  /// The program to call, which a test points at whatever it has.
  final String binary;

  /// Writes [configuration] as the whole of this workspace's configuration.
  ///
  /// Everything is written at once and nothing is appended: a workspace is
  /// derived from a recipe and a placement, so a file left from an earlier run
  /// would describe infrastructure nobody asked for any more.
  File write(Map<String, Object?> configuration) {
    if (!workspace.existsSync()) workspace.createSync(recursive: true);

    return workspace.childFile(tofuConfigurationName)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(configuration));
  }

  /// Downloads the providers the configuration names.
  Future<bool> init() => _succeeds(<String>['init', '-input=false', '-no-color']);

  /// Says what applying would do, without doing it.
  ///
  /// It is what `deploy --plan` prints for a provisioned resource, and it is
  /// also the only way to know whether an apply would create anything at all.
  Future<String?> plan() async {
    final ProcessOutcome outcome = await _run(<String>['plan', '-input=false', '-no-color']);

    return outcome.succeeded ? outcome.stdout : null;
  }

  /// Creates what the configuration describes.
  Future<bool> apply() => _succeeds(<String>['apply', '-input=false', '-auto-approve', '-no-color']);

  /// Destroys what this workspace created.
  Future<bool> destroy() => _succeeds(<String>['destroy', '-input=false', '-auto-approve', '-no-color']);

  /// What the configuration declares under `output`, flattened to strings.
  ///
  /// The values are what a consumer connects with, so they are read back as
  /// text: a port that a provider returns as a number is a port a connection
  /// string needs as characters.
  Future<Map<String, String>?> outputs() async {
    final ProcessOutcome outcome = await _run(<String>['output', '-json', '-no-color']);
    if (!outcome.succeeded) {
      globals.logger.printError(outcome.stderr.trim());

      return null;
    }

    final Object? decoded = jsonDecode(outcome.stdout);
    if (decoded is! Map<String, Object?>) return const <String, String>{};

    return <String, String>{
      for (final MapEntry<String, Object?> entry in decoded.entries)
        if (entry.value case final Map<String, Object?> held) entry.key: '${held['value']}',
    };
  }

  Future<ProcessOutcome> _run(List<String> arguments) {
    globals.logger.printTrace('[tofu] ${<String>[binary, ...arguments].join(' ')}');

    return globals.processRunner.observe(
      <String>[binary, ...arguments],
      workingDirectory: workspace.path,
      environment: <String, String>{'TF_PLUGIN_CACHE_DIR': _pluginCache().path},
    );
  }

  /// The shared provider cache, created the first time it is asked for.
  ///
  /// It belongs to the machine and not to a project, so it is reached without
  /// one: a workspace can be applied from anywhere, and the providers it needs
  /// are the same wherever it is.
  Directory _pluginCache() {
    final Directory cache = stackHome().childDirectory(pluginCacheDirectoryName);
    if (!cache.existsSync()) cache.createSync(recursive: true);

    return cache;
  }

  Future<bool> _succeeds(List<String> arguments) async {
    final ProcessOutcome outcome = await _run(arguments);
    if (outcome.succeeded) return true;

    globals.logger.printError(outcome.stderr.trim().isEmpty ? outcome.stdout.trim() : outcome.stderr.trim());

    return false;
  }
}
