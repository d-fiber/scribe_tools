import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const String _root = '../..';

const String _modules = '$_root/scribe/host/dependencies';

/// The mandatory packages, in the submodule that carries them.
const String _packages = '$_root/scribe/host/packages';

Directory get _modulesDir => Directory(_modules);

List<File> get _manifests => <String>[_modules, _packages]
    .map(Directory.new)
    .where((Directory root) => root.existsSync())
    .expand(
      (Directory root) => root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((File file) => p.basename(file.path) == 'scribe.yaml'),
    )
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

// A package groups its ops by subject, so one manifest can back several
// slices of the same template: `ops/valkery/docker-compose.yaml` next to
// `ops/queue/docker-compose.yaml`.
List<File> _fragments(File manifest, String template) {
  final Directory ops = Directory(p.join(manifest.parent.path, 'ops'));
  if (!ops.existsSync()) return const <File>[];

  return <File>[
    File(p.join(ops.path, template)),
    for (final Directory subject in ops.listSync().whereType<Directory>()) File(p.join(subject.path, template)),
  ].where((File file) => file.existsSync()).toList();
}

String _assembled(String base, String template) {
  final List<String> sources = <String>[File(base).readAsStringSync()];
  for (final File manifest in _manifests) {
    for (final File fragment in _fragments(manifest, template)) {
      sources.add(fragment.readAsStringSync());
    }
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


/// Whether [export] is something the manifest's owner actually declares.
bool _declaresExport(File manifest, String export, String frameworkDeno) {
  if (p.isWithin(_modules, manifest.path)) return frameworkDeno.contains('"$export"');

  final File deno = File(p.join(manifest.parent.path, 'deno.json'));
  if (!deno.existsSync()) return false;

  return (jsonDecode(deno.readAsStringSync()) as Map<String, dynamic>)['name'] == export;
}

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
        final Set<String> declared = _infraList(_read(manifest), 'services').toSet();
        for (final File fragment in _fragments(manifest, 'docker-compose.yaml')) {
          for (final RegExpMatch match
              in RegExp(r'^  ([a-z0-9-]+):$', multiLine: true).allMatches(fragment.readAsStringSync())) {
            if (!declared.contains(match.group(1))) {
              undeclared.add('${p.relative(fragment.path, from: _modules)} → ${match.group(1)}');
            }
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
        // A module that ships one contract names the file; a package that
        // groups its contracts by subject names the directory holding them.
        final Object? proto = map['protocol'];
        if (proto is String &&
            !File(p.join(module, proto)).existsSync() &&
            !Directory(p.join(module, proto)).existsSync()) {
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

    test('every declared export is declared by the package that holds the module', () {
      // A module the framework owns is an export subpath of the framework's own
      // deno.json. A module in the packages submodule is a package of its own,
      // so what it announces is that package's name.
      final String deno = File('$_modules/deno.json').readAsStringSync();
      final List<String> unknown = <String>[
        for (final File manifest in _manifests)
          if (_read(manifest)['export'] case final String export)
            if (!_declaresExport(manifest, export, deno)) '${p.relative(manifest.path, from: _modules)} → $export',
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
