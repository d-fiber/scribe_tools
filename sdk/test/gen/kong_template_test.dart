import 'dart:io';

import 'package:sdk/commands/gen/code/generators/config/kong.dart';
import 'package:sdk/core/template/merge.dart';
import 'package:sdk/core/template/render.dart';
import 'package:sdk/ops/dependencies.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

final RegExp _placeholder = RegExp(r'\{\{(\w+)\}\}');

const List<String> _expectedPlaceholders = <String>[
  'admin_cors_origins',
  'app_cors_origins',
  'app_key_consumers',
  'realtime_cors_origins',
  'storage_cors_origins',
];

final Dependencies _dependencies = Dependencies.load(
  roots: <Directory>[
    Directory('../../scribe/host/dependencies'),
    Directory('../../scribe/host/packages'),
  ],
);

String _base() => File('../../scribe/templates/ops/gateway/kong.yml').readAsStringSync();

String _template() => mergeYamlDocuments(_base(), _dependencies.fragmentsFor('kong.yml', _dependencies.all));

String _render(String template) => renderTemplate('kong.yml', template, <String, String>{
  'app_key_consumers': consumerBlock(<String, List<String>>{
    'app': <String>['app-key-1'],
    'admin': <String>['admin-key-1'],
  }),
  for (final String name in _expectedPlaceholders)
    if (name != 'app_key_consumers') name: originsBlock(<String>['https://example.test']),
});

void main() {
  group('the kong.yml template of the SDK', () {
    test('declares exactly the placeholders the generator resolves', () {
      final List<String> found =
          _placeholder.allMatches(_template()).map((RegExpMatch m) => m.group(1)!).toSet().toList()..sort();

      expect(found, _expectedPlaceholders);
    });

    test('renders to a document with no placeholder left', () {
      expect(_render(_template()), isNot(matches(_placeholder)));
    });

    test('renders to parseable YAML', () {
      expect(() => loadYaml(_render(_template())), returnsNormally);
    });

    test('renders the app and admin consumers into the consumers list', () {
      final YamlMap document = loadYaml(_render(_template())) as YamlMap;
      final List<String> usernames = <String>[
        for (final YamlMap consumer in (document['consumers'] as YamlList).cast<YamlMap>())
          consumer['username'] as String,
      ];

      expect(usernames, containsAll(<String>['app', 'admin']));
    });

    test('renders every cors block with the configured origin', () {
      final YamlMap document = loadYaml(_render(_template())) as YamlMap;
      int corsBlocks = 0;

      for (final YamlMap service in (document['services'] as YamlList).cast<YamlMap>()) {
        for (final YamlMap plugin in (service['plugins'] as YamlList? ?? YamlList()).cast<YamlMap>()) {
          if (plugin['name'] != 'cors') continue;
          corsBlocks++;
          expect((plugin['config'] as YamlMap)['origins'], <String>['https://example.test']);
        }
      }

      expect(corsBlocks, 4);
    });

    test('a module that is not mounted takes its gateway blocks with it', () {
      final YamlMap document = loadYaml(_render(mergeYamlDocuments(_base(), <YamlFragment>[]))) as YamlMap;
      final List<String> names = <String>[
        for (final YamlMap service in (document['services'] as YamlList).cast<YamlMap>()) service['name'] as String,
      ];

      expect(names, isNot(contains('realtime-v1-ws')));
      expect(names, contains('api-admin'), reason: 'le socle, lui, reste entier');
    });
  });
}
