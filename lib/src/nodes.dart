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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';

/// What a node is called, and what the gateway does for it.
///
/// A node is declared in `config.yaml` and served by the directory of the same
/// name. The directory alone arms nothing: a project that writes one and
/// declares nothing gets no route, no key and no quota, which is what makes a
/// folder someone left behind harmless.
class ProjectNode {
  /// Describes the node named [name].
  const ProjectNode({
    required this.name,
    required this.versions,
    required this.facesOutward,
    required this.requiresApiKey,
    required this.origins,
    required this.keyHeader,
    required this.callsPerSecond,
    required this.callsPerMinute,
    required this.maxBodyMb,
    required this.timeoutSec,
  });

  /// The node's name, which is the directory that serves it.
  final String name;

  /// The versions this node serves, in order, at least one.
  ///
  /// A node whose directory holds `v1/` and `v2/` serves both. One that holds
  /// its routes directly serves `v1`, because a project that never versioned
  /// anything is on its first version whether it said so or not.
  final List<String> versions;

  /// Whether the outside may call this node, or only the deployment itself.
  ///
  /// A node that faces inward gets no gateway route at all, which is the only
  /// thing that keeps an internal surface off the public domain.
  final bool facesOutward;

  /// Whether the gateway asks a caller for this node's application key.
  ///
  /// False by default: the gateway answers anyone who reaches the node, and
  /// what the application checks is what guards it. A node that says otherwise
  /// gets a door in front of that, and the key, the consumer and the access
  /// list that go with it.
  final bool requiresApiKey;

  /// The browser origins the gateway lets call this node.
  final List<String> origins;

  /// The header a caller carries this node's application key in.
  final String keyHeader;

  /// How many calls one address may make in a second.
  final int callsPerSecond;

  /// How many calls one address may make in a minute.
  final int callsPerMinute;

  /// The largest request body this node accepts, in megabytes.
  ///
  /// The gateway answers 413 to a bigger one before the node spends memory
  /// reading it, whatever content type the request claims.
  final int maxBodyMb;

  /// How long the gateway waits for this node to answer, in seconds.
  ///
  /// The connection is held for the whole time, so a node answering in
  /// milliseconds should not be allowed to hold one for a minute.
  final int timeoutSec;

  /// Whether this node holds its routes under a directory per version.
  ///
  /// It changes where the gateway sends a call and nothing else: a versioned
  /// node is reached at `/<version>/<node>/` and served from `<node>/<version>/`,
  /// so the public address keeps the version in front where every client already
  /// writes it, and the tree keeps the node in front where the routes are.
  bool get isVersioned => versions.length > 1 || (versions.length == 1 && versions.first != kImplicitVersion);

  /// The group the access list admits, which only this node's key belongs to.
  String get aclGroup => '${name}_key';

  /// The gateway service name serving [version] of this node.
  String serviceNameFor(String version) => 'api-$name-$version';

  /// The public path [version] of this node answers under.
  String publicPathFor(String version) => '/$version/$name/';

  /// The path the upstream serves [version] of this node from.
  String upstreamPathFor(String version) => isVersioned ? '/$name/$version/' : '/$name/';
}

/// The version a node is on when its directory holds no version at all.
const String kImplicitVersion = 'v1';

/// What a version directory is called: the letter, then the number.
final RegExp kVersionDirectory = RegExp(r'^v[0-9]+$');

/// The quota a node is given when the project names none.
///
/// It is deliberately tight. A quota too low is noticed on the first call, and
/// a quota too high is noticed the day someone abuses it.
const int kDefaultCallsPerSecond = 20;

/// The minute half of [kDefaultCallsPerSecond].
const int kDefaultCallsPerMinute = 400;

/// The body a node accepts when the project names none, in megabytes.
///
/// Low on purpose. A node that receives uploads says by how much; the ones that
/// only ever read JSON have no reason to pay for it.
const int kDefaultMaxBodyMb = 10;

/// How long the gateway waits when the project names nothing, in seconds.
const int kDefaultTimeoutSec = 30;

/// The nodes a project declares, read from its manifest.
class Nodes {
  const Nodes._(this.all);

  /// Every node the manifest declares, sorted by name.
  final List<ProjectNode> all;

  /// The ones the gateway serves, which is every node facing outward.
  List<ProjectNode> get facingOutward => all.where((ProjectNode node) => node.facesOutward).toList();

  /// Reads the nodes of [project], or of the one the command is running in.
  ///
  /// Throws a [ToolExit] naming every node whose directory is missing. The
  /// framework refuses the same mismatch when the worker starts, and refusing it
  /// here means it is named before anything is written rather than after a
  /// container has already come up.
  factory Nodes.load({Project? project}) {
    final Project target = project ?? globals.project;
    final List<String> names = List<String>.of(target.manifest.nodeNames)..sort();
    final List<String> fallback = target.manifest.origins;

    final List<String> missing = <String>[
      for (final String name in names)
        if (!target.lib.childDirectory(name).existsSync()) name,
    ];
    if (missing.isNotEmpty) {
      throwToolExit(
        'config.yaml declares ${missing.length} node(s) with no directory to serve: ${missing.join(', ')}.\n'
        'A node is served by lib/<name>/, so either write the directory or drop the declaration.',
      );
    }

    _warnAboutStrayDirectories(target, names);

    return Nodes._(<ProjectNode>[
      for (final String name in names)
        ProjectNode(
          name: name,
          versions: _versionsOf(target, name),
          facesOutward: target.manifest.nodeFacesOutward(name),
          requiresApiKey: target.manifest.nodeRequiresApiKey(name),
          origins: target.manifest.nodeOrigins(name) ?? fallback,
          keyHeader: target.manifest.nodeKeyHeader(name) ?? 'x-$name-key',
          callsPerSecond: target.manifest.nodeCallsPerSecond(name) ?? kDefaultCallsPerSecond,
          callsPerMinute: target.manifest.nodeCallsPerMinute(name) ?? kDefaultCallsPerMinute,
          maxBodyMb: target.manifest.nodeMaxBodyMb(name) ?? kDefaultMaxBodyMb,
          timeoutSec: target.manifest.nodeTimeoutSec(name) ?? kDefaultTimeoutSec,
        ),
    ]);
  }

  /// The versions [name] serves, read from what its directory holds.
  ///
  /// Throws a [ToolExit] when the directory holds both version directories and
  /// routes of its own, since there is no answer to what the loose ones are a
  /// version of.
  static List<String> _versionsOf(Project project, String name) {
    final Directory directory = project.lib.childDirectory(name);
    final List<String> versions = <String>[];
    bool loose = false;

    for (final FileSystemEntity entry in directory.listSync()) {
      final String basename = globals.fs.path.basename(entry.path);
      if (basename.startsWith('.') || basename.startsWith('_')) continue;

      if (entry is Directory && kVersionDirectory.hasMatch(basename)) {
        versions.add(basename);
      } else {
        loose = true;
      }
    }

    if (versions.isEmpty) return <String>[kImplicitVersion];
    if (loose) {
      throwToolExit(
        'lib/$name/ holds both version directories and routes of its own. '
        'Move the loose ones under a version, or drop the version directories.',
      );
    }

    return versions..sort();
  }

  /// Says so when `lib/` holds a directory no node declares.
  ///
  /// `lib/` holds nodes and nothing else, so such a directory is a route tree
  /// the project believes is live and that nothing serves. It is a warning and
  /// not a refusal: a directory being written before its declaration is a
  /// reasonable half-hour, and losing a whole assembly over it is not.
  static void _warnAboutStrayDirectories(Project project, List<String> declared) {
    if (!project.lib.existsSync()) return;

    final List<String> stray =
        <String>[
            for (final FileSystemEntity entry in project.lib.listSync())
              if (entry is Directory) globals.fs.path.basename(entry.path),
          ]
          ..removeWhere((String name) => name.startsWith('.') || name.startsWith('_') || declared.contains(name))
          ..sort();
    if (stray.isEmpty) return;

    globals.logger.printWarning(
      'lib/ holds ${stray.length} directory that no node declares: ${stray.join(', ')}. '
      'Nothing serves them until config.yaml names them under api.nodes.',
    );
  }
}
