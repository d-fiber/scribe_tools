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
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/forge/protocol/protocol_bridge_process.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

Directory _package() => fs.directory('/tree/foundation')..createSync(recursive: true);

void _write(Directory package, String relativePath, String contents) {
  final File file = fs.file(p.join(package.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

List<String> _relativePaths(Directory package, List<File> found) =>
    found.map((File file) => p.relative(file.path, from: package.path)).toList();

void main() {
  setUp(() => fs = MemoryFileSystem.test());

  test('answers nothing for a package directory that does not exist', () {
    expect(protocolSourceFiles(fs.directory('/tree/missing')), isEmpty);
  });

  test('finds a @Proto class wherever it sits, not only under protocol/', () {
    final Directory package = _package();
    _write(package, 'lib/proto/cache.ts', '@Proto("cache")\nexport class CacheProtocol {}');

    expect(_relativePaths(package, protocolSourceFiles(package)), <String>['lib/proto/cache.ts']);
  });

  test('ignores a .ts file that never names the decorator', () {
    final Directory package = _package();
    _write(package, 'lib/run.ts', 'export function run() {}');

    expect(protocolSourceFiles(package), isEmpty);
  });

  test('ignores a hand-written .proto sitting next to a @Proto class', () {
    final Directory package = _package();
    _write(package, 'protocol/legacy.proto', 'syntax = "proto3";');
    _write(package, 'lib/proto/cache.ts', '@Proto("cache")\nexport class CacheProtocol {}');

    expect(_relativePaths(package, protocolSourceFiles(package)), <String>['lib/proto/cache.ts']);
  });

  test('skips node_modules and a dotted directory such as .scribe', () {
    final Directory package = _package();
    _write(package, 'lib/proto/cache.ts', '@Proto("cache")\nexport class CacheProtocol {}');
    _write(package, 'node_modules/dep/index.ts', '@Proto("dep")\nexport class DepProtocol {}');
    _write(package, '.scribe/gen/proto/cache.proto', 'syntax = "proto3";');

    expect(_relativePaths(package, protocolSourceFiles(package)), <String>['lib/proto/cache.ts']);
  });

  test('comes back sorted by path, several contracts found', () {
    final Directory package = _package();
    _write(package, 'lib/proto/queue.ts', '@Proto("queue")\nexport class QueueProtocol {}');
    _write(package, 'lib/proto/cache.ts', '@Proto("cache")\nexport class CacheProtocol {}');

    expect(_relativePaths(package, protocolSourceFiles(package)), <String>['lib/proto/cache.ts', 'lib/proto/queue.ts']);
  });
}
