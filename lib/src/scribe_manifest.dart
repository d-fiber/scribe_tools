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
import 'package:yaml/yaml.dart';

/// The shortest password `api.auth` is allowed to accept.
const int kMinPasswordLength = 8;

/// One reason a manifest cannot be used yet.
class ManifestProblem {
  /// Reports [field] as unusable for [reason].
  const ManifestProblem(this.field, this.reason);

  /// The field it is about, written as a dotted path such as `api.cors`.
  final String field;

  /// What is wrong with it, and what to write instead.
  final String reason;

  @override
  String toString() => '$field: $reason';
}

/// A project's `config.yaml`, read and checked.
///
/// Reading is case-insensitive on keys and resolves `env(NAME)` references
/// against the environment, so nothing above ever sees a raw reference. The
/// checks are gathered in [problems] rather than thrown one by one: a user
/// filling in a new manifest is told everything that is left, not the first
/// thing that stopped the parser.
class ScribeManifest {
  const ScribeManifest._(this.file, this.document);

  /// The fields a manifest is unusable without.
  static const List<String> requiredFields = <String>['name'];

  /// The manifest in [file], or null when it is missing or is not a YAML mapping.
  static ScribeManifest? loadFrom(File file) {
    if (!file.existsSync()) return null;

    final Object? parsed = _plain(loadYaml(file.readAsStringSync()));
    if (parsed is! Map<String, Object?>) return null;

    return ScribeManifest._(file, parsed);
  }

  /// The manifest in [file].
  ///
  /// Throws a [ToolExit] when it is missing or is not a YAML mapping.
  static ScribeManifest load(File file) {
    final ScribeManifest? manifest = loadFrom(file);
    if (manifest != null) return manifest;

    throwToolExit(
      '${file.path} is missing or is not a YAML mapping.\n'
      'Copy config.example.yaml next to it and fill it in.',
    );
  }

  /// The file this was read from.
  final File file;

  /// The parsed YAML, as plain maps and lists.
  final Map<String, Object?> document;

  /// The project's name, as it is shown to a user.
  String get name => _string(<String>['name']) ?? '';

  /// Where the dashboard is served, empty when it is not served at all.
  ///
  /// An empty value is a choice and not an omission: Caddy opens no site block
  /// for it, and asks for no certificate in a name nobody gave it.
  String get dashboard => _string(<String>['dashboard']) ?? '';

  /// Where the API answers, empty when something in front of the stack routes it.
  ///
  /// Filled, Caddy terminates TLS on that host and sends everything to the
  /// gateway. Empty, the stack listens on its port and a proxy, a load balancer
  /// or an ingress does the rest, which is the deployment this says nothing
  /// about on purpose.
  String get apiUrl => _string(<String>['api', 'url']) ?? '';

  /// The address the project's mail is sent from.
  String get email => _string(<String>['email']) ?? '';

  /// The URL scheme the mobile application is opened by.
  String get deeplinkScheme => _string(<String>['app', 'deeplink_scheme']) ?? '';

  /// The key the geocoding service is called with.
  String get geocodingApiKey => _string(<String>['integrations', 'geocoding_api_key']) ?? '';

  /// The packages this project mounts, empty when it names none.
  ///
  /// The key is `dependencies:`, and it is the only one read.
  List<String> get packages => packageSources.keys.toList();

  /// Where each package this project mounts comes from, empty for one the checkout carries.
  ///
  /// The key is `dependencies:`, and it is the only one read.
  ///
  /// An entry is a name on its own for a package the checkout ships, a name
  /// carrying `sdk:` which says the same thing out loud, or a name carrying
  /// `path:` for one the project wrote or vendored. All are mounted the same way
  /// afterwards: a package nobody here wrote is reached exactly like a package
  /// shipped with the framework.
  ///
  /// The source is written down and never searched for. A name that could mean
  /// the checkout's package or the project's, depending on what happens to sit on
  /// disk, is a name that means something different on another machine. Anything
  /// that is neither `path:` nor `sdk:` is refused rather than read as a default,
  /// because a mistyped key would otherwise quietly mount the wrong package.
  ///
  /// ```yaml
  /// dependencies:
  ///   - auth
  ///   - billing:
  ///       path: ../billing
  ///   - realtime:
  ///       sdk: scribe
  /// ```
  Map<String, String> get packageSources {
    final Object? value = read(<String>['dependencies']);
    if (value is! List) return const <String, String>{};

    final Map<String, String> sources = <String, String>{};
    for (final Object? entry in value) {
      if (entry is Map && entry.length == 1) {
        final String name = entry.keys.first.toString().trim();
        final Object? source = entry.values.first;
        if (name.isEmpty) continue;

        if (source == null) {
          sources[name] = '';
          continue;
        }

        if (source is! Map) {
          throwToolExit(
            '${file.path}: "$name" carries $source, which says nothing about where it comes from.\n'
            'Write the name on its own for a package this checkout ships, or give it a path:.',
          );
        }

        final Object? path = source['path'];
        final Object? sdk = source['sdk'];
        final Iterable<String> unknown = source.keys
            .map((Object? key) => key.toString())
            .where((String key) => key != 'path' && key != 'sdk');

        if (unknown.isNotEmpty) {
          throwToolExit(
            '${file.path}: "$name" is given ${unknown.join(', ')}, which is no source this knows.\n'
            'A package comes from a path: or from sdk:, and a name on its own means the checkout.',
          );
        }

        if (path != null && sdk != null) {
          throwToolExit(
            '${file.path}: "$name" is given both a path: and an sdk:, so where it comes from '
            'depends on which one is read first.',
          );
        }

        sources[name] = path?.toString().trim() ?? '';
        continue;
      }

      final String name = entry.toString().trim();
      if (name.isNotEmpty) sources[name] = '';
    }
    return sources;
  }

  /// The origins allowed to call the API.
  List<String> get origins => _strings(<String>['api', 'cors']);

  /// Every node this project arms, in the order the manifest wrote them.
  ///
  /// They sit under `api.nodes` and not directly under `api`, which already
  /// carries `auth`, `config` and `docs`: at the same level those three would
  /// read as nodes named after themselves. A directory under `lib/` that is not
  /// named here is served by nothing: the declaration is what arms a node, and
  /// the directory is only what it serves.
  List<String> get nodeNames {
    final Object? value = read(<String>['api', 'nodes']);
    if (value is! Map) return const <String>[];

    return <String>[for (final Object? key in value.keys) key.toString().trim()]
      ..removeWhere((String name) => name.isEmpty);
  }

  /// Whether the outside may call [node], true unless the manifest says otherwise.
  ///
  /// The default is the useful one: a node exists to be called, and the one that
  /// does not is the exception a project writes a line for.
  bool nodeFacesOutward(String node) => read(<String>['api', 'nodes', node, 'public']) != false;

  /// Whether [node] asks the gateway for an application key, false by default.
  ///
  /// A node that says nothing is answered by the gateway to anyone who reaches
  /// it, and guarded by what the application itself checks. Asking for a key
  /// here adds a door in front of that, which is what a node holding an
  /// administration surface wants and what a public one does not.
  bool nodeRequiresApiKey(String node) => read(<String>['api', 'nodes', node, 'api_key']) == true;

  /// The origins a node lets a browser call it from, or null when it says nothing.
  ///
  /// A node that says nothing takes the ones the whole API declares, which is
  /// the ordinary case: a second list is written only when one audience is
  /// reached from somewhere the others are not.
  List<String>? nodeOrigins(String node) =>
      read(<String>['api', 'nodes', node, 'cors']) == null ? null : _strings(<String>['api', 'nodes', node, 'cors']);

  /// The header a caller carries this node's application key in, or null.
  String? nodeKeyHeader(String node) => _string(<String>['api', 'nodes', node, 'key_header']);

  /// How many calls a second this node admits from one address, or null.
  int? nodeCallsPerSecond(String node) => _int(<String>['api', 'nodes', node, 'rate_limit', 'sec']);

  /// The largest body this node accepts, in megabytes, or null.
  int? nodeMaxBodyMb(String node) => _int(<String>['api', 'nodes', node, 'max_body_mb']);

  /// How long the gateway waits for this node to answer, in seconds, or null.
  int? nodeTimeoutSec(String node) => _int(<String>['api', 'nodes', node, 'timeout_sec']);

  /// How many calls a minute this node admits from one address, or null.
  int? nodeCallsPerMinute(String node) => _int(<String>['api', 'nodes', node, 'rate_limit', 'min']);

  /// The documented API surfaces, each with the title and description it declares.
  ///
  /// A surface whose entry is not a mapping is dropped, and a missing title or
  /// description simply does not appear.
  Map<String, Map<String, String>> get docsSurfaces {
    final Object? value = read(<String>['api', 'docs']);
    if (value is! Map) return const <String, Map<String, String>>{};

    return <String, Map<String, String>>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.value case final Map<Object?, Object?> surface)
          entry.key.toString(): <String, String>{
            for (final String field in <String>['title', 'description'])
              if (surface[field] case final Object found) field: found.toString().trim(),
          },
    };
  }

  /// The value at [path], or null when any segment of it is absent.
  ///
  /// Keys are matched without regard to case, and nothing is resolved: an
  /// `env(NAME)` reference comes back as it was written.
  Object? read(List<String> path) {
    Object? node = document;

    for (final String key in path) {
      if (node is! Map) return null;

      Object? found;
      for (final MapEntry<Object?, Object?> entry in node.entries) {
        if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
          found = entry.value;
          break;
        }
      }
      node = found;
    }

    return node;
  }

  /// Everything standing between this manifest and a project that runs.
  ///
  /// All the checks run, every time: a user filling in a new manifest is told
  /// everything that is left rather than the first thing that failed.
  List<ManifestProblem> get problems => <ManifestProblem>[
    ..._committedSecrets(),
    ..._missingRequiredFields(),
    ..._originProblems(),
  ];

  /// Whether this manifest has no [problems] left.
  bool get isComplete => problems.isEmpty;

  /// Refuses the run when this manifest still has [problems].
  ///
  /// Throws a [ToolExit] listing every one of them.
  void ensureComplete() {
    final List<ManifestProblem> found = problems;
    if (found.isEmpty) return;

    final StringBuffer buffer = StringBuffer('${file.path} is not usable yet:\n');
    for (final ManifestProblem problem in found) {
      buffer.writeln('  $problem');
    }

    throwToolExit(buffer.toString().trimRight());
  }

  /// Every field whose name says secret and whose value is one, written in plain.
  ///
  /// `config.yaml` is committed, so a value written there is published the
  /// moment the repository is. A field is suspect when its name contains one of
  /// [secretFieldNames], and it is cleared by being empty or by holding an
  /// [envReference] instead of a value.
  List<ManifestProblem> _committedSecrets() {
    final List<ManifestProblem> found = <ManifestProblem>[];

    void walk(Object? node, List<String> path) {
      if (node is Map) {
        for (final MapEntry<Object?, Object?> entry in node.entries) {
          walk(entry.value, <String>[...path, entry.key.toString()]);
        }
        return;
      }
      if (node is! String) return;

      final String field = path.last.toLowerCase();
      if (!secretFieldNames.any(field.contains)) return;

      final String value = node.trim();
      if (value.isEmpty || envReference.hasMatch(value)) return;

      found.add(
        ManifestProblem(
          path.join('.'),
          'holds a secret in a file meant to be committed. Write env(${_envNameFor(path)}) and put the value in .env',
        ),
      );
    }

    walk(document, const <String>[]);
    return found;
  }

  static String _envNameFor(List<String> path) =>
      path.where((String segment) => segment != 'integrations').join('_').toUpperCase();

  List<ManifestProblem> _missingRequiredFields() => <ManifestProblem>[
    for (final String field in requiredFields)
      if ((_string(<String>[field]) ?? '').isEmpty) ManifestProblem(field, 'required, and it is empty'),
  ];

  List<ManifestProblem> _originProblems() {
    final Object? value = read(<String>['api', 'cors']);
    if (value == null) {
      return const <ManifestProblem>[
        ManifestProblem('api.cors', 'required: at least one origin allowed to call the API'),
      ];
    }
    if (value is! List || value.isEmpty) {
      return const <ManifestProblem>[
        ManifestProblem('api.cors', 'must be a non-empty list, e.g. ["https://admin.example.com"]'),
      ];
    }

    return <ManifestProblem>[
      for (final Object? entry in value)
        if (!_origin.hasMatch(entry.toString().trim()))
          ManifestProblem('api.cors', '"$entry" must be scheme and host only, with no path and no trailing slash'),
    ];
  }

  String? _string(List<String> path) {
    final Object? value = read(path);
    if (value == null) return null;

    return resolve(value.toString().trim(), field: path.join('.'));
  }

  /// [value] with an `env(NAME)` reference replaced by what the environment holds.
  ///
  /// A value that is not a reference comes back untouched. [field] names the
  /// manifest entry in the error.
  ///
  /// Throws a [ToolExit] when the variable is unset or empty, since a command
  /// running on a half-resolved manifest fails later and further away.
  String resolve(String value, {required String field}) {
    final RegExpMatch? reference = envReference.firstMatch(value);
    if (reference == null) return value;

    final String variable = reference.namedGroup('name')!;
    final String? found = globals.platform.environment[variable];

    if (found == null || found.isEmpty) {
      throwToolExit(
        '$field reads env($variable), and $variable is not set.\n'
        'Put it in .env, or export it before running the command.',
      );
    }

    return found;
  }

  int? _int(List<String> path) {
    final Object? value = read(path);
    if (value is int) return value;
    if (value == null) return null;

    return int.tryParse(value.toString().trim());
  }

  List<String> _strings(List<String> path) {
    final Object? value = read(path);
    if (value is! List) return const <String>[];

    return value.map((Object? entry) => entry.toString().trim()).where((String entry) => entry.isNotEmpty).toList();
  }

  @override
  String toString() => 'ScribeManifest(${file.path})';
}

/// The words that make a field name suspect, matched anywhere inside it.
const List<String> secretFieldNames = <String>[
  'secret',
  'password',
  'token',
  'private_key',
  'access_key',
  'api_key',
  'client_secret',
  'auth_token',
];

/// The whole-value form `env(NAME)`, which stands in for a value kept in `.env`.
///
/// It has to be the whole value: a reference embedded in a longer string is not
/// one, so nothing is ever half-substituted.
final RegExp envReference = RegExp(r'^env\((?<name>[A-Z][A-Z0-9_]*)\)$');

final RegExp _origin = RegExp(r'^https?://[A-Za-z0-9.-]+(:\d+)?$');

Object? _plain(Object? node) {
  if (node is YamlMap) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in node.entries) entry.key.toString(): _plain(entry.value),
    };
  }
  if (node is YamlList) return node.map(_plain).toList();
  return node;
}

/// The addresses a project serves, all derived from the one domain it declares.
class ProjectUrls {
  /// Holds the addresses derived from the domain a project declares.
  const ProjectUrls({
    required this.main,
    required this.admin,
    required this.app,
    required this.intra,
    required this.vpnDomain,
  });

  /// The public site.
  final String main;

  /// The back office.
  final String admin;

  /// The client application.
  final String app;

  /// The internal tools, reachable through the VPN.
  final String intra;

  /// The host the VPN answers on, a bare domain rather than an address.
  final String vpnDomain;
}

/// The addresses derived from [raw], the domain `config.yaml` declares.
///
/// [raw] is reduced to a bare domain first: the scheme, a trailing slash, a
/// leading `www.` and anything after the host are dropped, so the four
/// addresses come out the same whether the manifest wrote `example.com` or
/// `https://www.example.com/`.
ProjectUrls deriveUrls(String raw) {
  final String domain = raw
      .trim()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .split('/')
      .first;

  return ProjectUrls(
    main: 'https://$domain',
    admin: 'https://admin.$domain',
    app: 'https://app.$domain',
    intra: 'https://intra.$domain',
    vpnDomain: 'vpn.$domain',
  );
}
