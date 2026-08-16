// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:file/file.dart';
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:yaml/yaml.dart';

const int kMinPasswordLength = 8;

class ManifestProblem {
  const ManifestProblem(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => '$field — $reason';
}

class ScribeManifest {
  const ScribeManifest._(this.file, this.document);

  static const List<String> requiredFields = <String>['name', 'url', 'email'];

  static ScribeManifest? loadFrom(File file) {
    if (!file.existsSync()) return null;

    final Object? parsed = _plain(loadYaml(file.readAsStringSync()));
    if (parsed is! Map<String, Object?>) return null;

    return ScribeManifest._(file, parsed);
  }

  static ScribeManifest load(File file) {
    final ScribeManifest? manifest = loadFrom(file);
    if (manifest != null) return manifest;

    throwToolExit(
      '${file.path} is missing or is not a YAML mapping.\n'
      'Copy config.example.yaml next to it and fill it in.',
    );
  }

  final File file;
  final Map<String, Object?> document;

  String get name => _string(<String>['name']) ?? '';

  String get url => _string(<String>['url']) ?? '';

  String get email => _string(<String>['email']) ?? '';

  String get sdk => (read(<String>['sdk'])?.toString().trim() ?? '').toLowerCase();

  String get deeplinkScheme => _string(<String>['app', 'deeplink_scheme']) ?? '';

  String get geocodingApiKey => _string(<String>['integrations', 'geocoding_api_key']) ?? '';

  List<String> get dependencies => _strings(<String>['dependencies']);

  List<String> get origins => _strings(<String>['api', 'config', 'origins']);

  List<String> get allowedCountries =>
      _strings(<String>['api', 'config', 'allowed_countries']).map((String code) => code.toUpperCase()).toList();

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

  List<ManifestProblem> get problems => <ManifestProblem>[
    ..._committedSecrets(),
    ..._missingRequiredFields(),
    ..._sdkProblems(),
    ..._originProblems(),
    ..._countryProblems(),
    ..._passwordPolicyProblems(),
    ..._smtpProblems(),
  ];

  bool get isComplete => problems.isEmpty;

  void ensureComplete() {
    final List<ManifestProblem> found = problems;
    if (found.isEmpty) return;

    final StringBuffer buffer = StringBuffer('${file.path} is not usable yet:\n');
    for (final ManifestProblem problem in found) {
      buffer.writeln('  $problem');
    }

    throwToolExit(buffer.toString().trimRight());
  }

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
          'holds a secret in a file meant to be committed — write env(${_envNameFor(path)}) and put the value in .env',
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
        ManifestProblem('api.config.origins', 'required — at least one origin allowed to call the API'),
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

class ProjectUrls {
  const ProjectUrls({
    required this.main,
    required this.admin,
    required this.app,
    required this.intra,
    required this.vpnDomain,
  });

  final String main;
  final String admin;
  final String app;
  final String intra;
  final String vpnDomain;
}

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