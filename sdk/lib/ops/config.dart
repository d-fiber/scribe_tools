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

import '../core/logger.dart';
import '../core/paths/infra_files.dart';

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

dynamic _lookup(dynamic doc, List<String> path) {
  dynamic node = doc;
  for (final String key in path) {
    if (node is! YamlMap) return null;
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
  if (value == null || (value is YamlList && value.isEmpty)) {
    return {
      'api.config.origins': 'Required at least one origin allowed to call api-admin (e.g. https://admin.example.com)',
    };
  }
  if (value is! YamlList) {
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
  if (value == null || (value is YamlMap && value.isEmpty)) {
    return {'api.config.smtp': 'Required at least noreply and account (e.g. noreply: { host, port, user, pass })'};
  }
  if (value is! YamlMap) {
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
    if (account is! YamlMap) {
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
  if (value is! YamlList) {
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

final RegExp _broadcastEntityName = RegExp(r'^[a-z][a-z0-9_]*$');
const List<String> _broadcastEventNames = ['inserted', 'updated', 'deleted'];
const List<String> _broadcastScopes = ['admin', 'user', 'admins', 'users'];

List<String> _broadcastScopeList(dynamic raw) {
  if (raw is YamlList) return raw.map((dynamic e) => e.toString().trim()).toList();
  return [raw.toString().trim()];
}

Map<String, String> _broadcastErrors(dynamic doc) {
  final dynamic value = _lookup(doc, ['api', 'broadcast']);
  if (value == null) return const <String, String>{};
  if (value is! YamlMap) {
    return {'api.broadcast': 'Must be a map of named entities (e.g. brand: { events })'};
  }

  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final String name = entry.key.toString();
    final String prefix = 'api.broadcast.$name';
    if (!_broadcastEntityName.hasMatch(name)) {
      return {prefix: 'Invalid entity name must be lowercase letters, digits, underscore, starting with a letter'};
    }

    final dynamic node = entry.value;
    if (node is! YamlMap) {
      return {prefix: 'Must be a map with events'};
    }

    final dynamic events = _lookup(node, ['events']);
    if (events == null || (events is YamlMap && events.isEmpty)) {
      return {
        '$prefix.events':
            'Required a map of event → scope(s), e.g. { updated: [admin, admins], deleted: admins }',
      };
    }
    if (events is! YamlMap) {
      return {
        '$prefix.events': 'Must be a map of event → scope(s) (${_broadcastScopes.join(", ")})',
      };
    }

    for (final MapEntry<dynamic, dynamic> eventEntry in events.entries) {
      final String eventName = eventEntry.key.toString();
      final String eventPrefix = '$prefix.events.$eventName';
      if (!_broadcastEventNames.contains(eventName)) {
        return {eventPrefix: 'Unknown event "$eventName" must be one of: ${_broadcastEventNames.join(", ")}'};
      }

      final List<String> scopes = _broadcastScopeList(eventEntry.value);
      if (scopes.isEmpty) {
        return {eventPrefix: 'Must have at least one scope (${_broadcastScopes.join(", ")})'};
      }
      for (final String scope in scopes) {
        if (!_broadcastScopes.contains(scope)) {
          return {eventPrefix: 'Unknown scope "$scope" must be one of: ${_broadcastScopes.join(", ")}'};
        }
      }
    }
  }

  return const <String, String>{};
}

class Config {
  Config(this.values, this.generation, this._doc);

  final Map<String, String> values;
  final Map<String, List<String>> generation;
  final dynamic _doc;

  String get(String key) => values[key] ?? '';
  List<String> getList(String key) => generation[key] ?? const <String>[];

  List<String> getPath(List<String> path, {bool upper = false}) {
    final dynamic value = _lookup(_doc, path);
    if (value is! YamlList) return const <String>[];
    return value
        .map((dynamic e) => e.toString().trim())
        .map((String e) => upper ? e.toUpperCase() : e)
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  List<BroadcastEntity> getBroadcastEntities() {
    final dynamic value = _lookup(_doc, ['api', 'broadcast']);
    if (value is! YamlMap) return const <BroadcastEntity>[];

    final List<BroadcastEntity> out = <BroadcastEntity>[];
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final dynamic node = entry.value;
      if (node is! YamlMap) continue;
      final dynamic eventsValue = _lookup(node, ['events']);
      final Map<String, List<String>> events = <String, List<String>>{};
      if (eventsValue is YamlMap) {
        for (final MapEntry<dynamic, dynamic> eventEntry in eventsValue.entries) {
          events[eventEntry.key.toString()] = _broadcastScopeList(eventEntry.value);
        }
      }
      out.add(BroadcastEntity(name: entry.key.toString(), events: events));
    }
    out.sort((BroadcastEntity a, BroadcastEntity b) => a.name.compareTo(b.name));
    return out;
  }

  Map<String, Map<String, String>> getSmtpAccounts() {
    final dynamic value = _lookup(_doc, ['api', 'config', 'smtp']);
    if (value is! YamlMap) return const <String, Map<String, String>>{};

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final dynamic account = entry.value;
      if (account is! YamlMap) continue;
      out[entry.key.toString()] = {
        for (final String field in _smtpAccountFields) field: (_lookup(account, [field]) ?? '').toString().trim(),
      };
    }
    return out;
  }

  static Config read() {
    final File file = InfraFiles.tree.configYaml;
    if (!file.existsSync()) {
      _fail(
        'config.yaml not found copy config.example.yaml and fill in your values:\n'
        '  cp ${file.parent.path}/config.example.yaml ${file.path}',
      );
    }

    final dynamic doc = loadYaml(file.readAsStringSync());
    final Map<String, String> values = <String, String>{};
    if (doc is YamlMap) _flatten(doc, '', values);
    return Config(values, _readGeneration(doc), doc);
  }

  static Map<String, List<String>> _readGeneration(dynamic doc) {
    final Map<String, List<String>> out = <String, List<String>>{};
    if (doc is! YamlMap) return out;
    final dynamic generation = doc['generation'];
    if (generation is! YamlMap) return out;

    for (final MapEntry<dynamic, dynamic> entry in generation.entries) {
      final dynamic value = entry.value;
      if (value is! YamlList) continue;
      out[entry.key.toString()] = value
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    return out;
  }

  static const Set<String> _transparentGroups = {'INTEGRATIONS'};

  static void _flatten(YamlMap map, String prefix, Map<String, String> out) {
    for (final MapEntry<dynamic, dynamic> entry in map.entries) {
      final String rawKey = entry.key.toString();
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(rawKey)) continue;
      final String key = rawKey.toUpperCase();
      final dynamic value = entry.value;
      if (value is YamlMap) {
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
      ..._broadcastErrors(_doc),
    };
    if (missing.isEmpty) return;

    final int pad = missing.keys.map((String k) => k.length).reduce(max);
    final StringBuffer buffer = StringBuffer('Missing required fields in config.yaml:\n\n');
    for (final MapEntry<String, String> entry in missing.entries) {
      buffer.writeln('  • ${entry.key.padRight(pad)}  ${entry.value}');
    }
    buffer.write('\n  Edit ${InfraFiles.tree.configYaml.path} and re-run.');
    _fail(buffer.toString());
  }

  String get fingerprint => sha256.convert(utf8.encode('${get('NAME')}|${get('URL')}')).toString();
}

class BroadcastEntity {
  BroadcastEntity({required this.name, required this.events});

  final String name;
  final Map<String, List<String>> events;
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
