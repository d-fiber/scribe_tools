import 'dart:io';

import 'package:sdk/core/template/merge.dart';
import 'package:sdk/ops/dependencies.dart';
import 'package:sdk/ops/hardware.dart';
import 'package:sdk/ops/sizing_rules.dart';
import 'package:sdk/core/template/render.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

final RegExp _placeholder = RegExp(r'\{\{(\w+)\}\}');

/// The paths no checkout carries, because Docker creates them on first start.
const Set<String> _runtimeDataDirs = <String>{
  './scribe/postgres',
  './scribe/storage',
  './scribe/opensearch',
};

/// The mounts resolved from the SDK root, once `{{sdk_root}}` is rendered.
const String _sdkRoot = './scribe';

/// The generated output, once `{{alchemy_dir}}` is rendered.
const String _generated = './.example';

/// What the project owns at its root, next to `lib/`. `assets/` carries the
/// branding, and the compose mounts it read only.
const List<String> _projectRoots = <String>['./lib/', './assets'];

const List<String> _templateNames = <String>[
  'docker-compose.yaml',
  'resources.yaml',
  'replicas.yaml',
  'tuning.yaml',
];

const Hardware _hardware = Hardware(cores: 8, threads: 16, memoryGb: 32);

Map<String, String> get _values => <String, String>{
  ...const SizingRules(_hardware).resolve(),
  'app_name': 'Example',
  'app_name_snake': 'example',
  'sdk_root': './scribe',
  'alchemy_dir': '.example',
};

final Dependencies _dependencies = Dependencies.load(root: Directory('../../scribe/host/dependencies'));

List<YamlFragment> _fragments(String name) => _dependencies.fragmentsFor(name, _dependencies.all);

String _base(String name) => File('../../scribe/templates/ops/docker/$name').readAsStringSync();

String _template(String name) => mergeYamlDocuments(_base(name), _fragments(name));

String _renderWith(String name, List<YamlFragment> fragments) =>
    renderTemplate(name, mergeYamlDocuments(_base(name), fragments), _values);

String _render(String name) => _renderWith(name, _fragments(name));

Set<String> _serviceNames(String name, List<YamlFragment> fragments) =>
    ((loadYaml(_renderWith(name, fragments)) as YamlMap)['services'] as YamlMap).keys.cast<String>().toSet();

void main() {
  group('the docker templates of the repo', () {
    for (final String name in _templateNames) {
      test('$name resolves every placeholder it declares', () {
        expect(() => _render(name), returnsNormally);
      });

      test('$name renders to parseable YAML', () {
        expect(() => loadYaml(_render(name)), returnsNormally);
      });
    }

    test('the rendered compose leaves no placeholder behind', () {
      expect(_render('docker-compose.yaml'), isNot(matches(_placeholder)));
    });

    test('every template placeholder is a known sizing or identity value', () {
      final Set<String> declared = <String>{
        for (final String name in _templateNames)
          ..._placeholder.allMatches(_template(name)).map((RegExpMatch m) => m.group(1)!),
      };

      expect(declared.difference(_values.keys.toSet()), isEmpty);
    });
  });

  group('the compose host mounts', () {
    List<String> hostPaths() {
      final YamlMap services = (loadYaml(_render('docker-compose.yaml')) as YamlMap)['services'] as YamlMap;
      return <String>[
        for (final YamlMap service in services.values.cast<YamlMap>())
          for (final String volume in (service['volumes'] as YamlList? ?? YamlList()).cast<String>())
            if (volume.startsWith('./')) volume.split(':').first,
      ];
    }

    test('every mounted source exists, except the generated ones', () {
      final List<String> missing = <String>[
        for (final String path in hostPaths())
          if (!path.startsWith('$_generated/') &&
              !_runtimeDataDirs.contains(path) &&
              !File('../../$path').existsSync() &&
              !Directory('../../$path').existsSync())
            path,
      ];

      expect(missing, isEmpty);
    });

    test('every mount belongs either to the SDK or to the project, never in between', () {
      final Set<String> strays = <String>{
        for (final String path in hostPaths())
          if (!path.startsWith('$_sdkRoot/') &&
              !_projectRoots.any(path.startsWith) &&
              !path.startsWith('$_generated/'))
            path,
      };

      expect(strays, isEmpty, reason: 'a mount that is neither SDK nor project blocks extracting scribe/');
    });

    test('the generated sources it mounts are the ones gen code writes', () {
      expect(
        hostPaths().where((String path) => path.startsWith('$_generated/')).toSet(),
        <String>{
          '$_generated/ops/gateway/kong.yml',
          '$_generated/docs/admin.yaml',
          '$_generated/docs/app.yaml',
          '$_generated/docs/dist/admin',
          '$_generated/docs/dist/app',
          '$_generated/docs/dist/landing',
          '$_generated/sdk/js',
        },
      );
    });
  });

  group('the compose SMTP wiring', () {
    YamlMap service(String name) =>
        ((loadYaml(_render('docker-compose.yaml')) as YamlMap)['services'] as YamlMap)[name] as YamlMap;

    test('no include is left pointing at the deleted smtp compose', () {
      expect((loadYaml(_render('docker-compose.yaml')) as YamlMap)['include'], isNull);
      expect(File('../../scribe/templates/ops/docker/docker-compose.smtp.yaml').existsSync(), isFalse);
    });

    test('auth reads the GoTrue account written to .env by gen code', () {
      final YamlMap environment = service('auth')['environment'] as YamlMap;

      for (final String key in <String>[
        'GOTRUE_SMTP_ADMIN_EMAIL',
        'GOTRUE_SMTP_HOST',
        'GOTRUE_SMTP_PORT',
        'GOTRUE_SMTP_USER',
        'GOTRUE_SMTP_PASS',
      ]) {
        expect(environment[key], r'${' '$key}', reason: key);
      }
    });

    test('api and functions read the two foundation accounts', () {
      for (final String name in <String>['api', 'functions']) {
        final YamlMap environment = service(name)['environment'] as YamlMap;
        for (final String account in <String>['ACCOUNT', 'NOREPLY']) {
          for (final String field in <String>['HOST', 'PORT', 'USER', 'PASS']) {
            final String key = 'SMTP_${account}_$field';
            expect(environment[key], r'${' '$key}', reason: '$name.$key');
          }
        }
      }
    });

    test('db still receives the payload encryption key', () {
      expect((service('db')['environment'] as YamlMap)['SMTP_ENCRYPTION_KEY'], r'${SMTP_ENCRYPTION_KEY}');
    });
  });

  group('the compose assembled from the dependency fragments', () {
    const List<String> overlays = <String>['resources.yaml', 'replicas.yaml', 'tuning.yaml'];

    test('a module brings its containers, and the base template no longer names them', () {
      expect(_serviceNames('docker-compose.yaml', <YamlFragment>[]), isNot(contains('realtime')));
      expect(_serviceNames('docker-compose.yaml', _fragments('docker-compose.yaml')), contains('realtime'));
    });

    test('no overlay sizes a service the compose does not define', () {
      for (final bool mounted in <bool>[false, true]) {
        List<YamlFragment> fragments(String name) => mounted ? _fragments(name) : <YamlFragment>[];
        final Set<String> defined = _serviceNames('docker-compose.yaml', fragments('docker-compose.yaml'));

        for (final String overlay in overlays) {
          expect(
            _serviceNames(overlay, fragments(overlay)).difference(defined),
            isEmpty,
            reason: '$overlay, module mounted: $mounted',
          );
        }
      }
    });

    test('every service a manifest declares is defined once assembled', () {
      final Set<String> defined = _serviceNames('docker-compose.yaml', _fragments('docker-compose.yaml'));
      final List<String> missing = <String>[
        for (final Dependency dependency in _dependencies.all)
          for (final String service in dependency.infra.services)
            if (!defined.contains(service)) '${dependency.path} → $service',
      ];

      expect(missing, isEmpty);
    });

    test('an overlay patches a service of the socle, never one of a module', () {
      final Set<String> socle = _serviceNames('docker-compose.yaml', <YamlFragment>[]);
      final List<String> strays = <String>[];
      int patched = 0;

      for (final Dependency dependency in _dependencies.all) {
        final YamlFragment? overlay = dependency.fragmentFor(overlayTemplate);
        if (overlay == null) continue;

        final String rendered = renderTemplate(
          overlayFileName(dependency.path),
          mergeYamlDocuments(overlayBase, <YamlFragment>[overlay]),
          _values,
        );
        for (final String service
            in ((loadYaml(rendered) as YamlMap)['services'] as YamlMap).keys.cast<String>()) {
          patched++;
          if (!socle.contains(service)) strays.add('${dependency.path} → $service');
        }
      }

      expect(patched, isNonZero, reason: 'sinon ce test ne prouve rien');
      expect(strays, isEmpty, reason: 'patcher le service d\'un module absent produirait un service sans image');
    });

    test('the socle never depends on a service an optional module owns', () {
      final Map<String, String> owner = <String, String>{
        for (final Dependency dependency in _dependencies.all)
          if (dependency.optional)
            for (final String service in dependency.infra.services) service: dependency.path,
      };

      final YamlMap services =
          (loadYaml(_renderWith('docker-compose.yaml', <YamlFragment>[])) as YamlMap)['services'] as YamlMap;

      final List<String> dangling = <String>[];
      for (final MapEntry<dynamic, dynamic> entry in services.entries) {
        final Object? on = (entry.value as YamlMap)['depends_on'];
        final Iterable<String> targets = switch (on) {
          YamlMap map => map.keys.cast<String>(),
          YamlList list => list.cast<String>(),
          _ => const <String>[],
        };
        for (final String target in targets) {
          if (owner.containsKey(target)) dangling.add('${entry.key} → $target (${owner[target]})');
        }
      }

      expect(dangling, isEmpty, reason: 'the unmounted module would leave a dependency on a service that is gone');
    });

    test('a replicated service never fixes its container name', () {
      final YamlMap replicated = (loadYaml(_render('replicas.yaml')) as YamlMap)['services'] as YamlMap;
      final YamlMap compose = (loadYaml(_render('docker-compose.yaml')) as YamlMap)['services'] as YamlMap;

      final List<String> clashes = <String>[
        for (final String service in replicated.keys.cast<String>())
          if ((compose[service] as YamlMap?)?['container_name'] != null) service,
      ];

      expect(replicated, isNotEmpty, reason: 'otherwise this test proves nothing');
      expect(
        clashes,
        isEmpty,
        reason:
            'Compose refuses the whole project, not just the service, when one carries '
            'container_name together with deploy.replicas',
      );
    });

    test('a fragment never redefines a service of the base', () {
      final Set<String> base = _serviceNames('docker-compose.yaml', <YamlFragment>[]);
      final List<String> collisions = <String>[
        for (final Dependency dependency in _dependencies.all)
          for (final String service in dependency.infra.services)
            if (dependency.fragment('docker-compose.yaml').existsSync() && base.contains(service))
              '${dependency.path} → $service',
      ];

      expect(collisions, isEmpty, reason: 'a duplicate key would break the merged YAML');
    });
  });
}
