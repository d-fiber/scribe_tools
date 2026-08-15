import 'dart:io';

import 'package:scribe/commands/gen/routes/discovered_route.dart';
import 'package:scribe/commands/gen/routes/discovered_source.dart';
import 'package:scribe/commands/gen/routes/emitter.dart';
import 'package:scribe/commands/gen/routes/scanner.dart';
import 'package:scribe/core/exception.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory _tree(Map<String, String> files) {
  final Directory root = Directory.systemTemp.createTempSync('scribe_routes_');
  final Directory src = Directory(p.join(root.path, 'lib', 'src'))..createSync(recursive: true);

  files.forEach((String path, String content) {
    final File file = File(p.join(src.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  });

  addTearDown(() => root.deleteSync(recursive: true));
  return root;
}

DiscoveredSource _source(Map<String, String> files) {
  final Directory root = _tree(files);
  return RouteScanner.scan(Directory(p.join(root.path, 'lib', 'src')), root.path);
}

List<DiscoveredRoute> _scan(Map<String, String> files) => _source(files).routes;

void main() {
  group('the route scanner', () {
    test('a file under a node folder becomes a path', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{'app/brand.ts': ''});

      expect(routes.single.node, 'app');
      expect(routes.single.path, '/brand');
    });

    test('index answers the folder it sits in', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{'app/brand/index.ts': ''});

      expect(routes.single.path, '/brand');
    });

    test('a bracketed segment becomes a path parameter', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{
        'app/brand/[brandId]/status.ts': '',
      });

      expect(routes.single.path, '/brand/:brandId/status');
    });

    test('nesting folders nests the path', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{
        'app/store/search/nearby.ts': '',
      });

      expect(routes.single.path, '/store/search/nearby');
    });

    test('an underscore keeps a file out of the routing', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{
        'app/brand/_guards.ts': '',
        'app/brand/index.ts': '',
      });

      expect(routes.map((DiscoveredRoute route) => route.path), <String>['/brand']);
    });

    test('a middleware applies to everything below it', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{
        'app/brand/_middleware.ts': '',
        'app/brand/index.ts': '',
        'app/brand/[brandId]/update.ts': '',
        'app/store.ts': '',
      });

      final DiscoveredRoute update = routes.firstWhere(
        (DiscoveredRoute route) => route.path == '/brand/:brandId/update',
      );
      final DiscoveredRoute store = routes.firstWhere(
        (DiscoveredRoute route) => route.path == '/store',
      );

      expect(update.branches, hasLength(1));
      expect(update.branches.single, endsWith('brand/_middleware.ts'));
      expect(store.branches, isEmpty);
    });

    test('a file and a folder claiming the same path is refused', () {
      expect(
        () => _scan(<String, String>{'app/brand.ts': '', 'app/brand/index.ts': ''}),
        throwsA(isA<CliException>()),
      );
    });

    test('a leftover _node.ts is refused instead of silently ignored', () {
      expect(
        () => _scan(<String, String>{'app/_node.ts': '', 'app/brand.ts': ''}),
        throwsA(isA<CliException>()),
      );
    });

    test('a node folder starting with an underscore is not a node', () {
      final DiscoveredSource source = _source(<String, String>{'_shared/helper.ts': ''});

      expect(source.routes, isEmpty);
      expect(source.nodes, isEmpty);
    });

    test('an empty node folder is still reported as a node', () {
      final Directory root = _tree(<String, String>{'app/brand.ts': ''});
      Directory(p.join(root.path, 'lib', 'src', 'admin')).createSync();

      final DiscoveredSource source = RouteScanner.scan(
        Directory(p.join(root.path, 'lib', 'src')),
        root.path,
      );

      expect(source.nodes, <String>['admin', 'app']);
      expect(source.routes, hasLength(1));
    });
  });

  group('the routes emitter', () {
    test('a project file becomes an aliased specifier', () {
      expect(specifierOf('lib/src/app/brand/index.ts'), '@app/src/app/brand/index.ts');
    });

    test('a middleware shared by two routes is imported once', () {
      final String rendered = RoutesEmitter(
        const DiscoveredSource(
          nodes: <String>['app'],
          routes: <DiscoveredRoute>[
            DiscoveredRoute(
              node: 'app',
              path: '/brand',
              file: 'lib/src/app/brand/index.ts',
              branches: <String>['lib/src/app/_middleware.ts'],
            ),
            DiscoveredRoute(
              node: 'app',
              path: '/store',
              file: 'lib/src/app/store.ts',
              branches: <String>['lib/src/app/_middleware.ts'],
            ),
          ],
        ),
      ).render('// header');

      expect('_middleware.ts'.allMatches(rendered).length, 1);
      expect(rendered, contains('node: "app"'));
      expect(rendered, contains('path: "/brand"'));
    });
  });
}
