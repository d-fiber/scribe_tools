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

  /// The field it is about, written as a dotted path such as `api.config.origins`.
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
  static const List<String> requiredFields = <String>['name', 'email'];

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

  /// The SDK this project targets, lowercased, empty when it names none.
  ///
  /// This one is read raw rather than through [resolve]: it names a directory,
  /// so an `env(...)` reference would be meaningless and saying so is the job
  /// of [problems].
  String get sdk => (read(<String>['sdk'])?.toString().trim() ?? '').toLowerCase();

  /// The URL scheme the mobile application is opened by.
  String get deeplinkScheme => _string(<String>['app', 'deeplink_scheme']) ?? '';

  /// The key the geocoding service is called with.
  String get geocodingApiKey => _string(<String>['integrations', 'geocoding_api_key']) ?? '';

  /// The packages this project mounts, empty when it names none.
  ///
  /// The key is `packages:`. A manifest that still spells it `dependencies:` is
  /// read all the same, and only when `packages:` is absent: the file belongs to
  /// the project rather than to the CLI, so a checkout written against the old
  /// name keeps working instead of failing at the first command with no way
  /// forward.
  List<String> get packages => packageSources.keys.toList();

  /// Where each package this project mounts comes from, empty for one the checkout carries.
  ///
  /// The key is `packages:`. A manifest that still spells it `dependencies:` is
  /// read all the same, and only when `packages:` is absent: the file belongs to
  /// the project rather than to the CLI, so a checkout written against the old
  /// name keeps working instead of failing at the first command with no way
  /// forward.
  ///
  /// An entry is a name on its own for a package the checkout ships, or a name
  /// carrying `path:` for one the project wrote or vendored. Both are mounted the
  /// same way afterwards: a package nobody here wrote is reached exactly like a
  /// package shipped with the framework.
  ///
  /// ```yaml
  /// packages:
  ///   - auth
  ///   - billing:
  ///       path: ../billing
  /// ```
  Map<String, String> get packageSources {
    Object? value = read(<String>['packages']);
    value ??= read(<String>['dependencies']);
    if (value is! List) return const <String, String>{};

    final Map<String, String> sources = <String, String>{};
    for (final Object? entry in value) {
      if (entry is Map && entry.length == 1) {
        final String name = entry.keys.first.toString().trim();
        final Object? source = entry.values.first;
        final Object? path = source is Map ? source['path'] : null;
        if (name.isNotEmpty) sources[name] = path?.toString().trim() ?? '';
        continue;
      }

      final String name = entry.toString().trim();
      if (name.isNotEmpty) sources[name] = '';
    }
    return sources;
  }

  /// Whether this project runs its own code in a worker process of its own.
  ///
  /// False by default, and false is the ordinary case: the host loads the
  /// project in its own process, and the `worker` container would be a second
  /// Deno nobody talks to. Saying true starts it and gives it a memory budget.
  bool get worker => read(<String>['worker']) == true;

  /// The origins allowed to call the API.
  List<String> get origins => _strings(<String>['api', 'config', 'origins']);

  /// The countries the firewall lets through, as uppercase ISO 3166-1 alpha-2 codes.
  List<String> get allowedCountries =>
      _strings(<String>['api', 'config', 'allowed_countries']).map((String code) => code.toUpperCase()).toList();

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
    ..._sdkProblems(),
    ..._originProblems(),
    ..._countryProblems(),
    ..._passwordPolicyProblems(),
    ..._smtpProblems(),
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

  List<ManifestProblem> _sdkProblems() {
    final Object? value = read(<String>['sdk']);
    if (value == null) return const <ManifestProblem>[];

    if (value is! String || value.trim().isEmpty) {
      return const <ManifestProblem>[
        ManifestProblem('sdk', 'must name one of the directories of scribe/sdk/, e.g. js'),
      ];
    }

    return const <ManifestProblem>[];
  }

  List<ManifestProblem> _missingRequiredFields() => <ManifestProblem>[
    for (final String field in requiredFields)
      if ((_string(<String>[field]) ?? '').isEmpty) ManifestProblem(field, 'required, and it is empty'),
  ];

  List<ManifestProblem> _originProblems() {
    final Object? value = read(<String>['api', 'config', 'origins']);
    if (value == null) {
      return const <ManifestProblem>[
        ManifestProblem('api.config.origins', 'required: at least one origin allowed to call the API'),
      ];
    }
    if (value is! List || value.isEmpty) {
      return const <ManifestProblem>[
        ManifestProblem('api.config.origins', 'must be a non-empty list, e.g. ["https://admin.example.com"]'),
      ];
    }

    return <ManifestProblem>[
      for (final Object? entry in value)
        if (!_origin.hasMatch(entry.toString().trim()))
          ManifestProblem(
            'api.config.origins',
            '"$entry" must be scheme and host only, with no path and no trailing slash',
          ),
    ];
  }

  List<ManifestProblem> _countryProblems() {
    final Object? value = read(<String>['api', 'config', 'allowed_countries']);
    if (value == null) return const <ManifestProblem>[];
    if (value is! List) {
      return const <ManifestProblem>[
        ManifestProblem('api.config.allowed_countries', 'must be a list of ISO 3166-1 alpha-2 codes, e.g. FR'),
      ];
    }

    return <ManifestProblem>[
      for (final Object? entry in value)
        if (!_countryCode.hasMatch(entry.toString().trim()))
          ManifestProblem('api.config.allowed_countries', '"$entry" is not a two-letter country code'),
    ];
  }

  List<ManifestProblem> _passwordPolicyProblems() {
    const List<String> path = <String>['api', 'auth', 'sign_in_with_email_and_password'];
    if (read(path) == null) return const <ManifestProblem>[];

    final List<ManifestProblem> found = <ManifestProblem>[];

    final Object? enabled = read(<String>[...path, 'enabled']);
    if (enabled is! bool) {
      found.add(const ManifestProblem('api.auth.sign_in_with_email_and_password.enabled', 'must be true or false'));
    }

    final Object? minLength = read(<String>[...path, 'password', 'min_length']);
    if (minLength is! int) {
      found.add(
        const ManifestProblem('api.auth.sign_in_with_email_and_password.password.min_length', 'must be a number'),
      );
    } else if (minLength < kMinPasswordLength) {
      found.add(
        ManifestProblem(
          'api.auth.sign_in_with_email_and_password.password.min_length',
          'must be at least $kMinPasswordLength, got $minLength',
        ),
      );
    }

    for (final String field in <String>['require_uppercase', 'require_lowercase', 'require_number']) {
      if (read(<String>[...path, 'password', field]) is! bool) {
        found.add(ManifestProblem('api.auth.sign_in_with_email_and_password.password.$field', 'must be true or false'));
      }
    }

    return found;
  }

  List<ManifestProblem> _smtpProblems() {
    final Object? value = read(<String>['api', 'config', 'smtp']);
    if (value == null) return const <ManifestProblem>[];
    if (value is! Map) {
      return const <ManifestProblem>[
        ManifestProblem('api.config.smtp', 'must be a map of named accounts, each with host, port, user and pass'),
      ];
    }

    final List<ManifestProblem> found = <ManifestProblem>[];

    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String account = entry.key.toString();

      if (!_accountName.hasMatch(account)) {
        found.add(ManifestProblem('api.config.smtp.$account', 'name must be lowercase letters, digits and underscore'));
        continue;
      }

      final Object? fields = entry.value;
      if (fields is! Map) {
        found.add(ManifestProblem('api.config.smtp.$account', 'must be a map with host, port, user and pass'));
        continue;
      }

      final bool blank = <String>[
        'host',
        'port',
        'user',
        'pass',
      ].every((String field) => (fields[field]?.toString().trim() ?? '').isEmpty);
      if (blank) continue;

      for (final String field in <String>['host', 'port', 'user', 'pass']) {
        if ((fields[field]?.toString().trim() ?? '').isEmpty) {
          found.add(ManifestProblem('api.config.smtp.$account.$field', 'required once the account is filled in'));
        }
      }
    }

    return found;
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

final RegExp _countryCode = RegExp(r'^[A-Za-z]{2}$');

final RegExp _accountName = RegExp(r'^[a-z][a-z0-9_]*$');

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
