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
import 'package:yaml/yaml.dart';

/// What a setting may be, kept closed on purpose.
///
/// A module says what a setting is, not how it is written out, so a type nobody
/// scaffolds has to be refused here rather than silently produce an empty value.
const Set<String> settingTypes = <String>{'string', 'integer', 'boolean', 'list', 'map'};

/// The key a scaffolded file carries the placement of a module's resources under.
const String deployKey = 'deploy';

/// One thing a module lets a project decide.
class Setting {
  /// Holds one setting as the module that owns it declared it.
  const Setting({required this.name, required this.doc, required this.type, required this.defaultValue});

  /// The key the project writes it under.
  final String name;

  /// The sentence written above it in the scaffolded file.
  ///
  /// It is the only documentation a project gets without opening the package, so
  /// it says what the setting decides rather than repeating its name.
  final String doc;

  /// One of [settingTypes], which decides how the default is written out.
  final String type;

  /// What the project gets until it decides otherwise.
  final Object? defaultValue;
}

/// What a module lets a project configure, and what it writes out.
///
/// The declaration is data by the time it reaches here: a package may author it
/// in TypeScript, but what ships beside the package and what the CLI reads is
/// the emitted document, the same way a `.proto` ships beside its stubs.
class Settings {
  /// Holds [settings] in the order the declaration listed them.
  Settings(List<Setting> settings) : settings = List<Setting>.unmodifiable(settings);

  /// Every setting the module exposes, in declaration order.
  final List<Setting> settings;

  /// Whether the module exposes anything at all.
  ///
  /// A module that exposes nothing gets no file scaffolded, which is the case of
  /// a package configured through its API rather than at deployment.
  bool get isEmpty => settings.isEmpty;

  /// The settings [file] declares, empty when it declares none.
  ///
  /// A declaration without a `settings` key is not an error: a module may need a
  /// resource and expose no setting, and both halves are optional.
  static Settings read(File file) {
    if (!file.existsSync()) return Settings(const <Setting>[]);

    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throwToolExit('${file.path}: the file must be a mapping.');
    }

    final Object? declared = document['settings'];
    if (declared == null) return Settings(const <Setting>[]);
    if (declared is! YamlMap) {
      throwToolExit('${file.path}: "settings" must be a mapping of name to declaration.');
    }

    return Settings(<Setting>[
      for (final MapEntry<Object?, Object?> entry in declared.entries) _readSetting('${entry.key}', entry.value, file),
    ]);
  }

  /// What each setting is worth, by the key a fragment reads it under.
  ///
  /// A key is `setting_<module>_<name>`, the same shape a resource output takes,
  /// because a fragment should not have to know which of the two it is reading.
  /// [chosen] is what the project wrote; a setting it left out keeps the default
  /// the module declared, so a fragment always has a value.
  Map<String, String> valuesFor(String module, Map<String, Object?> chosen) => <String, String>{
    for (final Setting setting in settings)
      'setting_${module}_${setting.name}': _flat(
        chosen.containsKey(setting.name) ? chosen[setting.name] : setting.defaultValue,
      ),
  };

  /// A setting as a fragment carries it, which is always text.
  ///
  /// A collection has no place in an environment variable, so it comes out as
  /// nothing rather than as something a service would misread: a setting a
  /// fragment reads is a scalar, and one that is not is read by the code.
  static String _flat(Object? value) => switch (value) {
    null => '',
    final bool held => '$held',
    final int held => '$held',
    final String held => held,
    _ => '',
  };

  /// The file a project edits, with every default written out and documented.
  ///
  /// The header says who wrote it and that it will not be written again, because
  /// a file a tool created is assumed to be a file a tool owns until it says
  /// otherwise, and this one belongs to whoever opens it.
  String scaffold({required String module, required String version}) {
    final StringBuffer out = StringBuffer()
      ..writeln('# configuration/$module.yaml')
      ..writeln('#')
      ..writeln('# Written by `scribe forge` from the ${<String>[module, version].join(' ').trim()}')
      ..writeln('# declaration. Values are the package defaults, and this file is yours to')
      ..writeln('# edit: `scribe forge` never overwrites it.');

    for (final Setting setting in settings) {
      out
        ..writeln()
        ..writeln('# ${setting.doc}')
        ..writeln('${setting.name}: ${_write(setting.defaultValue, setting.type)}');
    }

    return (out
          ..writeln()
          ..writeln('# Where each resource this package needs is placed, per target. A target')
          ..writeln('# that is not named here gets a container alongside the rest of the stack.')
          ..writeln('$deployKey: {}'))
        .toString();
  }

  static Setting _readSetting(String name, Object? entry, File file) {
    if (entry is! YamlMap) {
      throwToolExit('${file.path}: setting "$name" must be a mapping.');
    }

    final Object? type = entry['type'];
    if (type is! String || !settingTypes.contains(type)) {
      throwToolExit(
        '${file.path}: setting "$name" is a "$type", which is not a type. '
        'It is one of ${settingTypes.join(', ')}.',
      );
    }

    final Object? doc = entry['doc'];
    if (doc is! String || doc.trim().isEmpty) {
      throwToolExit('${file.path}: setting "$name" must carry a "doc" saying what it decides.');
    }

    if (!entry.containsKey('default')) {
      throwToolExit('${file.path}: setting "$name" must carry a "default", which is what a project gets.');
    }

    return Setting(name: name, doc: doc, type: type, defaultValue: entry['default']);
  }

  /// Writes [value] as the YAML a project reads, in flow style for collections.
  ///
  /// Flow style keeps a default on the line its comment sits above, which is
  /// what makes the scaffolded file readable when most defaults are empty.
  static String _write(Object? value, String type) {
    if (value == null) return type == 'list' ? '[]' : (type == 'map' ? '{}' : '""');
    if (value is String) return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    if (value is bool || value is int) return '$value';
    if (value is List) return '[${value.map((Object? e) => _write(e, 'string')).join(', ')}]';
    if (value is Map) {
      return '{${value.entries.map((MapEntry<Object?, Object?> e) => '${e.key}: ${_write(e.value, 'string')}').join(', ')}}';
    }

    return '""';
  }
}
