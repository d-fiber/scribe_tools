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

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_route.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_sink.dart';
import 'package:scribe_tools/src/commands/gen/routes/discovered_source.dart';
import 'package:scribe_tools/src/commands/gen/routes/emitter.dart';
import 'package:scribe_tools/src/commands/gen/routes/scanner.dart';
import 'package:scribe_tools/src/nodes.dart';
import 'package:test/test.dart';

Directory _tree(Map<String, String> files) {
  final Directory root = Directory.systemTemp.createTempSync('scribe_routes_');
  final Directory src = Directory(p.join(root.path, 'lib'))..createSync(recursive: true);

  files.forEach((String path, String content) {
    final File file = File(p.join(src.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  });

  addTearDown(() => root.deleteSync(recursive: true));
  return root;
}

DiscoveredSource _source(Map<String, String> files) => _sourceWith(files, root: const <String, String>{});

/// Scans a tree of [files] under `lib/`, plus [root] files under `lib/`.
///
/// The root `_logs.ts` is the only thing a project declares outside `lib/`,
/// so it is the only reason this takes two maps rather than one.
DiscoveredSource _sourceWith(Map<String, String> files, {required Map<String, String> root}) {
  final Directory tree = _tree(files);

  root.forEach((String path, String content) {
    final File file = File(p.join(tree.path, 'lib', path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  });

  return RouteScanner.scan(Directory(p.join(tree.path, 'lib')), tree.path);
}

List<DiscoveredRoute> _scan(Map<String, String> files) => _source(files).routes;

const ProjectNode _appNode = ProjectNode(
  name: 'app',
  versions: <String>['v1'],
  facesOutward: true,
  requiresApiKey: false,
  origins: <String>[],
  keyHeader: 'x-app-key',
  callsPerSecond: 20,
  callsPerMinute: 400,
  maxBodyMb: 10,
  timeoutSec: 30,
);

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
      final List<DiscoveredRoute> routes = _scan(<String, String>{'app/brand/[brandId]/status.ts': ''});

      expect(routes.single.path, '/brand/:brandId/status');
    });

    test('nesting folders nests the path', () {
      final List<DiscoveredRoute> routes = _scan(<String, String>{'app/store/search/nearby.ts': ''});

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
      final DiscoveredRoute store = routes.firstWhere((DiscoveredRoute route) => route.path == '/store');

      expect(update.branches, hasLength(1));
      expect(update.branches.single, endsWith('brand/_middleware.ts'));
      expect(store.branches, isEmpty);
    });

    test('a file and a folder claiming the same path is refused', () {
      expect(() => _scan(<String, String>{'app/brand.ts': '', 'app/brand/index.ts': ''}), throwsA(isA<ToolExit>()));
    });

    test('a leftover _node.ts is refused instead of silently ignored', () {
      expect(() => _scan(<String, String>{'app/_node.ts': '', 'app/brand.ts': ''}), throwsA(isA<ToolExit>()));
    });

    test('a node folder starting with an underscore is not a node', () {
      final DiscoveredSource source = _source(<String, String>{'_shared/helper.ts': ''});

      expect(source.routes, isEmpty);
      expect(source.nodes, isEmpty);
    });

    test('an empty node folder is still reported as a node', () {
      final Directory root = _tree(<String, String>{'app/brand.ts': ''});
      Directory(p.join(root.path, 'lib', 'admin')).createSync();

      final DiscoveredSource source = RouteScanner.scan(Directory(p.join(root.path, 'lib')), root.path);

      expect(source.nodes, <String>['admin', 'app']);
      expect(source.routes, hasLength(1));
    });
  });

  group('the log sink scanner', () {
    test('a project with no _logs.ts declares no sink', () {
      expect(_source(<String, String>{'app/brand.ts': ''}).sinks, isEmpty);
    });

    test('a _logs.ts at the root of lib answers for no node', () {
      final DiscoveredSource source = _sourceWith(
        <String, String>{'app/brand.ts': ''},
        root: <String, String>{'_logs.ts': ''},
      );

      expect(source.sinks.single.node, isNull);
      expect(source.sinks.single.file, 'lib/_logs.ts');
    });

    test('a _logs.ts at the root of a node answers for that node', () {
      final DiscoveredSource source = _source(<String, String>{'app/_logs.ts': '', 'admin/_logs.ts': ''});

      expect(source.sinks.map((DiscoveredSink sink) => sink.node), <String>['admin', 'app']);
      expect(source.sinks.first.file, 'lib/admin/_logs.ts');
    });

    test('the root sink comes before the nodes, and the nodes are sorted', () {
      final DiscoveredSource source = _sourceWith(
        <String, String>{'app/_logs.ts': '', 'admin/_logs.ts': ''},
        root: <String, String>{'_logs.ts': ''},
      );

      expect(source.sinks.map((DiscoveredSink sink) => sink.node), <String?>[null, 'admin', 'app']);
    });

    test('a node without a _logs.ts produces no entry at all', () {
      final DiscoveredSource source = _source(<String, String>{'app/_logs.ts': '', 'admin/brand.ts': ''});

      expect(source.sinks.map((DiscoveredSink sink) => sink.node), <String>['app']);
    });

    test('a _logs.ts deeper than a node root is not a sink', () {
      final DiscoveredSource source = _source(<String, String>{'app/brand/_logs.ts': ''});

      expect(source.sinks, isEmpty);
      expect(source.routes, isEmpty);
    });

    test('the emitter binds every sink to an import of its own', () {
      final String rendered = RoutesEmitter(
        const DiscoveredSource(
          nodes: <String>['app'],
          routes: <DiscoveredRoute>[],
          sinks: <DiscoveredSink>[
            DiscoveredSink(node: null, file: 'lib/_logs.ts'),
            DiscoveredSink(node: 'app', file: 'lib/app/_logs.ts'),
          ],
        ),
        declared: const <ProjectNode>[_appNode],
      ).render('// header');

      expect(rendered, contains('import * as _l0 from "@app/_logs.ts";'));
      expect(rendered, contains('import * as _l1 from "@app/app/_logs.ts";'));
      expect(rendered, contains('{ node: null, file: "lib/_logs.ts", module: _l0 },'));
      expect(rendered, contains('{ node: "app", file: "lib/app/_logs.ts", module: _l1 },'));
    });

    test('a project with no sink still exports the table the server reads', () {
      final String rendered = RoutesEmitter(
        const DiscoveredSource(nodes: <String>['app'], routes: <DiscoveredRoute>[]),
        declared: const <ProjectNode>[_appNode],
      ).render('// header');

      expect(rendered, contains('export const logSinks: readonly DiscoveredLogSink[] = [\n];'));
    });
  });

  group('the routes emitter', () {
    test('a project file becomes an aliased specifier', () {
      expect(specifierOf('lib/app/brand/index.ts'), '@app/app/brand/index.ts');
    });

    test('a middleware shared by two routes is imported once', () {
      final String rendered = RoutesEmitter(
        const DiscoveredSource(
          nodes: <String>['app'],
          routes: <DiscoveredRoute>[
            DiscoveredRoute(
              node: 'app',
              path: '/brand',
              file: 'lib/app/brand/index.ts',
              branches: <String>['lib/app/_middleware.ts'],
            ),
            DiscoveredRoute(
              node: 'app',
              path: '/store',
              file: 'lib/app/store.ts',
              branches: <String>['lib/app/_middleware.ts'],
            ),
          ],
        ),
        declared: const <ProjectNode>[_appNode],
      ).render('// header');

      expect('_middleware.ts'.allMatches(rendered).length, 1);
      expect(rendered, contains('node: "app"'));
      expect(rendered, contains('path: "/brand"'));
    });
  });
}
