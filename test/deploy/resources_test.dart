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
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:test/test.dart';

const String _declaration = '''
requires:
  - name: redis
    type: redis
''';

const String _recipe = '''
outputs:
  host: "redis"
  port: 6379
  url: "redis://:\${REDIS_PASSWORD}@redis:6379"
''';

void main() {
  late Directory root;

  File declare(String source) => root.childFile('$configurationFileName$kTemplateSuffix')..writeAsStringSync(source);

  Directory recipe(String type, String source, {String className = containerPlacement}) {
    root.childDirectory(recipesDirectoryName).childDirectory(type).childFile('$className.yaml$kTemplateSuffix')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    return root.childDirectory(recipesDirectoryName);
  }

  Resources read(File declaration, {Placement? placed}) => Resources.read(
    <File>[declaration],
    recipes: <Directory>[root.childDirectory(recipesDirectoryName)],
    placement: placed == null ? null : (String _) => placed,
  );

  setUp(() {
    root = MemoryFileSystem.test().directory('ops')..createSync(recursive: true);
  });

  group('a resource the socle declares', () {
    test('carries the outputs of the recipe that answered for it', () {
      recipe('redis', _recipe);

      final ResolvedResource resolved = read(declare(_declaration)).resolved.single;

      expect(resolved.resource.type, 'redis');
      expect(resolved.className, containerPlacement);
      expect(resolved.outputs['url'], r'redis://:${REDIS_PASSWORD}@redis:6379');
    });

    test('becomes one template value per output, keyed by resource and output', () {
      recipe('redis', _recipe);

      expect(read(declare(_declaration)).values, <String, String>{
        'resource_redis_host': 'redis',
        'resource_redis_port': '6379',
        'resource_redis_url': r'redis://:${REDIS_PASSWORD}@redis:6379',
      });
    });

    test('takes the recipe the target placed it on, not the container one', () {
      recipe('redis', _recipe);
      recipe('redis', 'outputs:\n  url: "\${REDIS_URL}"\n', className: externalPlacement);

      final ResolvedResource resolved = read(
        declare(_declaration),
        placed: const Placement(className: externalPlacement),
      ).resolved.single;

      expect(resolved.className, externalPlacement);
      expect(resolved.outputs['url'], r'${REDIS_URL}');
    });

    test('is refused when the recipe returns less than its type promises', () {
      recipe('redis', 'outputs:\n  host: "redis"\n');
      root
          .childDirectory(recipesDirectoryName)
          .childDirectory('redis')
          .childFile(contractFileName)
          .writeAsStringSync('outputs:\n  - host\n  - port\n  - url\n');

      expect(
        () => read(declare(_declaration)),
        throwsA(
          isA<ToolExit>().having(
            (ToolExit e) => e.message,
            'message',
            allOf(contains('returns no port, no url'), contains('promises host, port, url')),
          ),
        ),
      );
    });

    test('is taken when the recipe returns everything its type promises', () {
      recipe('redis', _recipe);
      root
          .childDirectory(recipesDirectoryName)
          .childDirectory('redis')
          .childFile(contractFileName)
          .writeAsStringSync('outputs:\n  - host\n  - port\n  - url\n');

      expect(read(declare(_declaration)).resolved.single.outputs.keys, containsAll(<String>['host', 'port', 'url']));
    });

    test('is refused by name and by type when no recipe answers for it', () {
      expect(
        () => read(declare(_declaration)),
        throwsA(
          isA<ToolExit>().having(
            (ToolExit e) => e.message,
            'message',
            allOf(contains('redis'), contains('No container recipe')),
          ),
        ),
      );
    });

    test('is refused when the declaration holds no list under "requires"', () {
      recipe('redis', _recipe);

      expect(
        () => read(declare('requires: redis\n')),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('requires'))),
      );
    });

    test('is refused when a required key is missing from an entry', () {
      recipe('redis', _recipe);

      expect(
        () => read(declare('requires:\n  - name: redis\n')),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('"type"'))),
      );
    });

    test('is refused when the recipe holds no mapping under "outputs"', () {
      recipe('redis', 'outputs: []\n');

      expect(
        () => read(declare(_declaration)),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('outputs'))),
      );
    });

    test('is refused when an output is neither text, a number nor a boolean', () {
      recipe('redis', 'outputs:\n  url: [a, b]\n');

      expect(
        () => read(declare(_declaration)),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('"url"'))),
      );
    });
  });
}
