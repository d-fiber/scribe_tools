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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import '../core/file_system_entity/paths.dart';
import '../core/file_system_entity/source.dart';
import '../core/logger.dart';

const Map<String, String> requiredFields = {
  'NAME': 'Project name',
  'URL': 'Base domain (e.g. example.com or https://example.com)',
  'EMAIL': "ACME (Let's Encrypt/ZeroSSL) registration email cert expiry notices go here",
  'GEOCODING_API_KEY': 'Google Maps Geocoding API key',
};

const Map<String, String> requiredGenerationLists = {};

const int minPasswordLength = 8;

const List<String> _passwordBoolFields = ['require_uppercase', 'require_lowercase', 'require_number'];

Never _fail(String message) {
  print('$ansiRed[config]$ansiReset $message');
  exit(1);
}

dynamic _toPlain(dynamic node) {
  if (node is YamlMap) {
    return {for (final MapEntry<dynamic, dynamic> e in node.entries) e.key.toString(): _toPlain(e.value)};
  }
  if (node is YamlList) return node.map(_toPlain).toList();
  return node;
}

dynamic _lookup(dynamic doc, List<String> path) {
  dynamic node = doc;
  for (final String key in path) {
    if (node is! Map) return null;
    dynamic found;
    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      if (entry.key.toString().toLowerCase() == key) {
        found = entry.value;
        break;
      }
    }
    node = found;
  }
  return node;
}

Map<String, String> _passwordPolicyErrors(dynamic doc) {
  final Map<String, String> errors = <String, String>{};
  const List<String> path = ['api', 'auth', 'sign_in_with_email_and_password'];

  final dynamic enabled = _lookup(doc, [...path, 'enabled']);
  if (enabled == null) {
    errors['api.auth.sign_in_with_email_and_password.enabled'] = 'Required must be true or false';
  } else if (enabled is! bool) {
    errors['api.auth.sign_in_with_email_and_password.enabled'] = 'Must be a boolean, true or false (got: $enabled)';
  }

  final List<String> passwordPath = [...path, 'password'];

  final dynamic minLength = _lookup(doc, [...passwordPath, 'min_length']);
  if (minLength == null) {
    errors['api.auth.sign_in_with_email_and_password.password.min_length'] =
        'Required minimum password length (number, >= $minPasswordLength)';
  } else if (minLength is! int) {
    errors['api.auth.sign_in_with_email_and_password.password.min_length'] = 'Must be a number (got: $minLength)';
  } else if (minLength < minPasswordLength) {
    errors['api.auth.sign_in_with_email_and_password.password.min_length'] =
        'Must be >= $minPasswordLength (got: $minLength)';
  }

  for (final String field in _passwordBoolFields) {
    final dynamic value = _lookup(doc, [...passwordPath, field]);
    if (value == null) {
      errors['api.auth.sign_in_with_email_and_password.password.$field'] = 'Required must be true or false';
    } else if (value is! bool) {
      errors['api.auth.sign_in_with_email_and_password.password.$field'] =
          'Must be a boolean, true or false (got: $value)';
    }
  }

  return errors;
}

final RegExp _originPattern = RegExp(r'^https?://[A-Za-z0-9.-]+(:\d+)?$');

Map<String, String> _originsErrors(dynamic doc) {
  final dynamic value = _lookup(doc, ['api', 'config', 'origins']);
  if (value == null || (value is List && value.isEmpty)) {
    return {
      'api.config.origins': 'Required at least one origin allowed to call api-admin (e.g. https://admin.example.com)',
    };
  }
  if (value is! List) {
    return {'api.config.origins': 'Must be a list of origins (e.g. ["https://admin.example.com"])'};
  }
  for (final dynamic entry in value) {
    final String origin = entry.toString().trim();
    if (!_originPattern.hasMatch(origin)) {
      return {
        'api.config.origins':
            'Invalid origin "$origin" must be scheme + host only, e.g. https://admin.example.com (no path or trailing slash)',
      };
    }
  }
  return const <String, String>{};
}

final RegExp _smtpAccountName = RegExp(r'^[a-z][a-z0-9_]*$');
const List<String> _smtpAccountFields = ['host', 'port', 'user', 'pass'];

const List<String> _requiredSmtpAccounts = ['noreply', 'account'];

Map<String, String> _smtpAccountErrors(dynamic doc) {
  final dynamic value = _lookup(doc, ['api', 'config', 'smtp']);
  if (value == null || (value is Map && value.isEmpty)) {
    return {'api.config.smtp': 'Required at least noreply and account (e.g. noreply: { host, port, user, pass })'};
  }
  if (value is! Map) {
    return {'api.config.smtp': 'Must be a map of named accounts (e.g. noreply: { host, port, user, pass })'};
  }

  for (final String required in _requiredSmtpAccounts) {
    if (_lookup(value, [required]) == null) {
      return {
        'api.config.smtp.$required': 'Required every project needs at least a noreply and an account SMTP identity',
      };
    }
  }

  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final String name = entry.key.toString();
    if (!_smtpAccountName.hasMatch(name)) {
      return {
        'api.config.smtp.$name':
            'Invalid account name must be lowercase letters, digits, underscore, starting with a letter',
      };
    }
    final dynamic account = entry.value;
    if (account is! Map) {
      return {'api.config.smtp.$name': 'Must be a map with host, port, user, pass'};
    }
    for (final String field in _smtpAccountFields) {
      final dynamic fieldValue = _lookup(account, [field]);
      if (fieldValue == null || fieldValue.toString().trim().isEmpty) {
        return {'api.config.smtp.$name.$field': 'Required'};
      }
    }
  }
  return const <String, String>{};
}

final RegExp _iso2CountryCode = RegExp(r'^[A-Za-z]{2}$');

Map<String, String> _countryAllowlistErrors(dynamic doc) {
  final dynamic value = _lookup(doc, ['api', 'config', 'allowed_countries']);
  if (value == null) return const <String, String>{};
  if (value is! List) {
    return {'api.config.allowed_countries': 'Must be a list of 2-letter ISO 3166-1 alpha-2 codes (e.g. FR, BE)'};
  }
  for (final dynamic entry in value) {
    final String code = entry.toString().trim();
    if (!_iso2CountryCode.hasMatch(code)) {
      return {'api.config.allowed_countries': 'Invalid country code "$code" must be 2 letters (ISO 3166-1 alpha-2)'};
    }
  }
  return const <String, String>{};
}

class Config {
  Config(this.values, this.generation, this._doc);

  final Map<String, String> values;
  final Map<String, List<String>> generation;
  final dynamic _doc;

  dynamic get doc => _doc;

  String get(String key) => values[key] ?? '';
  List<String> getList(String key) => generation[key] ?? const <String>[];

  List<String> getPath(List<String> path, {bool upper = false}) {
    final dynamic value = _lookup(_doc, path);
    if (value is! List) return const <String>[];
    return value
        .map((dynamic e) => e.toString().trim())
        .map((String e) => upper ? e.toUpperCase() : e)
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  Map<String, Map<String, String>> getSmtpAccounts() {
    final dynamic value = _lookup(_doc, ['api', 'config', 'smtp']);
    if (value is! Map) return const <String, Map<String, String>>{};

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final dynamic account = entry.value;
      if (account is! Map) continue;
      out[entry.key.toString()] = {
        for (final String field in _smtpAccountFields) field: (_lookup(account, [field]) ?? '').toString().trim(),
      };
    }
    return out;
  }

  /// La prose de chaque surface de doc, si le projet la declare.
  ///
  /// Le framework fournit le mecanisme et un defaut ; les mots qui decrivent
  /// l'API d'un projet appartiennent au projet.
  Map<String, Map<String, String>> getDocsSurfaces() {
    final dynamic value = _lookup(_doc, ['api', 'docs']);
    if (value is! Map) return const <String, Map<String, String>>{};

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final dynamic surface = entry.value;
      if (surface is! Map) continue;
      out[entry.key.toString()] = <String, String>{
        for (final String field in <String>['title', 'description'])
          if (_lookup(surface, <String>[field]) case final Object found) field: found.toString().trim(),
      };
    }
    return out;
  }

  static Config? _memo;

  /// La configuration du projet, lue depuis `config.yaml`.
  ///
  /// Le fichier est la source de verite et n'est jamais reecrit ni supprime par
  /// une commande de lecture — meme role que `pubspec.yaml` pour Flutter. Il a
  /// ete absorbe puis efface par un store chiffre jusqu'au 2026-08-14 ; voir
  /// `.claude/scripts/cli/infra.md`.
  static Future<Config> read() async {
    final Config? cached = _memo;
    if (cached != null) return cached;

    final Source file = Paths.kernel.config;
    if (!file.existsSync()) {
      _fail(
        'config.yaml not found at ${file.path}.\n\n'
        '  Copy config.example.yaml next to it and fill it in, or run `init`.',
      );
    }

    return _memo = buildFromDoc(parseDoc(await file.content()));
  }

  static dynamic parseDoc(String yamlText) => _toPlain(loadYaml(yamlText));

  static Config buildFromDoc(dynamic doc) {
    final Map<String, String> values = <String, String>{};
    if (doc is Map) _flatten(doc, '', values);
    return Config(values, _readGeneration(doc), doc);
  }

  static Map<String, List<String>> _readGeneration(dynamic doc) {
    final Map<String, List<String>> out = <String, List<String>>{};
    if (doc is! Map) return out;
    final dynamic generation = doc['generation'];
    if (generation is! Map) return out;

    for (final MapEntry<dynamic, dynamic> entry in generation.entries) {
      final dynamic value = entry.value;
      if (value is! List) continue;
      out[entry.key.toString()] = value
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    return out;
  }

  static const Set<String> _transparentGroups = {'INTEGRATIONS'};

  static void _flatten(Map<dynamic, dynamic> map, String prefix, Map<String, String> out) {
    for (final MapEntry<dynamic, dynamic> entry in map.entries) {
      final String rawKey = entry.key.toString();
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(rawKey)) continue;
      final String key = rawKey.toUpperCase();
      final dynamic value = entry.value;
      if (value is Map) {
        final String nextPrefix = _transparentGroups.contains(key) ? prefix : (prefix.isEmpty ? key : '${prefix}_$key');
        _flatten(value, nextPrefix, out);
        continue;
      }
      final String fullKey = prefix.isEmpty ? key : '${prefix}_$key';
      final String strValue = value?.toString() ?? '';
      if (strValue.isNotEmpty) out[fullKey] = strValue;
    }
  }

  void validate() {
    final Map<String, String> missing = {
      for (final MapEntry<String, String> field in requiredFields.entries)
        if (get(field.key).isEmpty) field.key: field.value,
      for (final MapEntry<String, String> field in requiredGenerationLists.entries)
        if (getList(field.key).isEmpty) 'generation.${field.key}': field.value,
      ..._passwordPolicyErrors(_doc),
      ..._countryAllowlistErrors(_doc),
      ..._originsErrors(_doc),
      ..._smtpAccountErrors(_doc),
    };
    if (missing.isEmpty) return;

    final int pad = missing.keys.map((String k) => k.length).reduce(max);
    final StringBuffer buffer = StringBuffer('Missing required fields in config.yaml:\n\n');
    for (final MapEntry<String, String> entry in missing.entries) {
      buffer.writeln('  • ${entry.key.padRight(pad)}  ${entry.value}');
    }
    buffer.write('\n  Edit ${Paths.kernel.config.path} and re-run.');
    _fail(buffer.toString());
  }

  String get fingerprint => sha256.convert(utf8.encode('${get('NAME')}|${get('URL')}')).toString();
}

class ProjectUrls {
  ProjectUrls({
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
  String domain = raw.trim();
  domain = domain.replaceFirst(RegExp(r'^https?://'), '');
  domain = domain.replaceFirst(RegExp(r'/+$'), '');
  domain = domain.replaceFirst(RegExp(r'^www\.'), '').split('/').first;

  return ProjectUrls(
    main: 'https://$domain',
    admin: 'https://admin.$domain',
    app: 'https://app.$domain',
    intra: 'https://intra.$domain',
    vpnDomain: 'vpn.$domain',
  );
}
