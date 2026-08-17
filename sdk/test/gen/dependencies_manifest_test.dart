import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const String _root = '../..';

const String _modules = '$_root/scribe/host/dependencies';

Directory get _modulesDir => Directory(_modules);

List<File> get _manifests => _modulesDir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((File file) => p.basename(file.path) == 'scribe.yaml')
    .toList()
  ..sort((File a, File b) => a.path.compareTo(b.path));

YamlMap _read(File manifest) => loadYaml(manifest.readAsStringSync()) as YamlMap;

List<String> _list(YamlMap map, String key) {
  final Object? value = map[key];
  if (value is! YamlList) return const <String>[];
  return value.cast<String>().toList();
}

List<String> _infraList(YamlMap map, String key) {
  final Object? infra = map['ops'];
  if (infra is! YamlMap) return const <String>[];
  return _list(infra, key);
}

File _fragment(File manifest, String template) => File(p.join(manifest.parent.path, 'ops', template));

String _assembled(String base, String template) {
  final List<String> sources = <String>[File(base).readAsStringSync()];
  for (final File manifest in _manifests) {
    final File fragment = _fragment(manifest, template);
    if (fragment.existsSync()) sources.add(fragment.readAsStringSync());
  }
  return sources.join('\n');
}

Set<String> _composeServices() => RegExp(r'^  ([a-z0-9-]+):$', multiLine: true)
    .allMatches(_assembled('$_root/scribe/templates/ops/docker/docker-compose.yaml', 'docker-compose.yaml'))
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

Set<String> _gatewayBlocks() => RegExp(r'^  - name: ([a-z0-9-]+)$', multiLine: true)
    .allMatches(_assembled('$_root/scribe/templates/ops/gateway/kong.yml', 'kong.yml'))
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

void main() {
  group('the dependency manifests', () {
    test('every module that has a mod.ts declares one', () {
      final List<String> missing = <String>[];
      for (final FileSystemEntity entity in _modulesDir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || p.basename(entity.path) != 'mod.ts') continue;
        final Directory module = entity.parent;
        if (p.split(p.relative(module.path, from: _modules)).contains('src')) continue;
        if (!File(p.join(module.path, 'scribe.yaml')).existsSync()) {
          missing.add(p.relative(module.path, from: _modules));
        }
      }

      expect(missing, isEmpty, reason: 'a module without a manifest is invisible to the four readers');
    });

    test('every declared service exists in the compose', () {
      final Set<String> services = _composeServices();
      final List<String> unknown = <String>[
        for (final File manifest in _manifests)
          for (final String service in _infraList(_read(manifest), 'services'))
            if (!services.contains(service)) '${p.relative(manifest.path, from: _modules)} → $service',
      ];

      expect(unknown, isEmpty);
    });

    test('a fragment defines nothing its manifest does not declare', () {
      final List<String> undeclared = <String>[];
      for (final File manifest in _manifests) {
        final File fragment = _fragment(manifest, 'docker-compose.yaml');
        if (!fragment.existsSync()) continue;

        final Set<String> declared = _infraList(_read(manifest), 'services').toSet();
        for (final RegExpMatch match
            in RegExp(r'^  ([a-z0-9-]+):$', multiLine: true).allMatches(fragment.readAsStringSync())) {
          if (!declared.contains(match.group(1))) {
            undeclared.add('${p.relative(fragment.path, from: _modules)} → ${match.group(1)}');
          }
        }
      }

      expect(undeclared, isEmpty, reason: 'the manifest has to stay the exact reading of the fragment');
    });

    test('every declared gateway block exists in kong.yml', () {
      final Set<String> blocks = _gatewayBlocks();
      final List<String> unknown = <String>[
        for (final File manifest in _manifests)
          for (final String block in _infraList(_read(manifest), 'gateway'))
            if (!blocks.contains(block)) '${p.relative(manifest.path, from: _modules)} → $block',
      ];

      expect(unknown, isEmpty);
    });

    test('every declared path exists on disk', () {
      final List<String> missing = <String>[];
      for (final File manifest in _manifests) {
        final YamlMap map = _read(manifest);
        final String module = manifest.parent.path;
        final Object? sql = map['sql'];
        if (sql is String && !Directory(p.join(module, sql)).existsSync()) {
          missing.add('${manifest.path} → $sql');
        }
        final Object? proto = map['protocol'];
        if (proto is String && !File(p.join(module, proto)).existsSync()) {
          missing.add('${manifest.path} → $proto');
        }
        for (final String route in _list(map, 'routes')) {
          if (!Directory('$_root/scribe/host/$route').existsSync()) {
            missing.add('${manifest.path} → $route');
          }
        }
      }

      expect(missing, isEmpty);
    });

    test('every declared export is declared by the module package', () {
      final String deno = File('$_modules/deno.json').readAsStringSync();
      final List<String> unknown = <String>[
        for (final File manifest in _manifests)
          if (_read(manifest)['export'] case final String export)
            if (!deno.contains('"$export"')) '${p.relative(manifest.path, from: _modules)} → $export',
      ];

      expect(unknown, isEmpty);
    });

    test('every required module is itself a declared module', () {
      final Set<String> declared = _manifests
          .map((File file) => p.relative(file.parent.path, from: _modules))
          .toSet();

      final List<String> dangling = <String>[
        for (final File manifest in _manifests)
          for (final String required in _list(_read(manifest), 'requires'))
            if (!declared.contains(required)) '${p.relative(manifest.path, from: _modules)} → $required',
      ];

      expect(dangling, isEmpty);
    });

    test('a module the host cannot start without is not marked optional', () {
      final Map<String, bool> optional = <String, bool>{
        for (final File manifest in _manifests)
          p.relative(manifest.parent.path, from: _modules): _read(manifest)['optional'] as bool,
      };

      expect(optional['security/auth'], isFalse, reason: '56 files of scribe/host/ import it');
      expect(optional['security/rbac'], isFalse, reason: 'the admin surface is guarded by it');
    });
  });
}
