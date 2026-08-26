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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/ops/fragments.dart';
import 'package:scribe_tools/src/ops/gateway.dart';
import 'package:test/test.dart';

const String _base = '''
services:
  - name: api-app
    url: http://api/app/
    routes:
      - name: api-app-route
        paths:
          - /v1/app/
''';

const String _storage = '''
services:
  - name: storage-v1
    url: http://storage:5000/
    routes:
      - name: storage-v1-route
        paths:
          - /storage/v1/
''';

const String _clashingPath = '''
services:
  - name: mirror-v1
    url: http://mirror:5000/
    routes:
      - name: mirror-v1-route
        paths:
          - /v1/app/
''';

const String _clashingName = '''
services:
  - name: mirror-v1
    url: http://mirror:5000/
    routes:
      - name: api-app-route
        paths:
          - /mirror/v1/
''';

String _merged(List<YamlFragment> fragments) => mergeYamlDocuments(_base, fragments);

void main() {
  group('the gateway of an assembled selection', () {
    test('reads every route a fragment contributed, and says which one wrote it', () {
      final List<YamlFragment> fragments = <YamlFragment>[const YamlFragment('storage', _storage)];
      final List<GatewayRoute> routes = routesOf(_merged(fragments), fragments);

      expect(routes.map((GatewayRoute route) => route.name), <String>['api-app-route', 'storage-v1-route']);
      expect(routes.map((GatewayRoute route) => route.origin), <String>['socle', 'storage']);
      expect(routes.last.paths, <String>['/storage/v1/']);
    });

    test('accepts two packages whose paths do not meet', () {
      final List<YamlFragment> fragments = <YamlFragment>[const YamlFragment('storage', _storage)];

      expect(() => refuseAmbiguousRoutes(routesOf(_merged(fragments), fragments)), returnsNormally);
    });

    test('refuses two routes on one path, which Kong would serve from only one of them', () {
      final List<YamlFragment> fragments = <YamlFragment>[const YamlFragment('mirror', _clashingPath)];

      expect(
        () => refuseAmbiguousRoutes(routesOf(_merged(fragments), fragments)),
        throwsA(
          isA<ToolExit>().having(
            (ToolExit exit) => exit.message,
            'message',
            allOf(contains('/v1/app/'), contains('mirror'), contains('socle')),
          ),
        ),
      );
    });

    test('refuses two routes of one name, which Kong refuses to start on', () {
      final List<YamlFragment> fragments = <YamlFragment>[const YamlFragment('mirror', _clashingName)];

      expect(
        () => refuseAmbiguousRoutes(routesOf(_merged(fragments), fragments)),
        throwsA(
          isA<ToolExit>().having(
            (ToolExit exit) => exit.message,
            'message',
            allOf(contains('api-app-route'), contains('mirror')),
          ),
        ),
      );
    });

    test('names a fragment that does not parse as no origin rather than failing the read', () {
      const List<YamlFragment> fragments = <YamlFragment>[YamlFragment('broken', 'services: [')];

      expect(() => routesOf(_base, fragments), returnsNormally);
    });
  });
}
