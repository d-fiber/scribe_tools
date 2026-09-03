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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/nodes.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;
late BufferLogger logger;

const String _manifest = '''
name: "notes"
api:
  url: "https://notes.example.com"
  cors:
    - "https://notes.example.com"
  nodes:
    app:
''';

Project _projectAt(String path) {
  fs.file('$path/config.yaml').createSync(recursive: true);
  fs.file('$path/config.yaml').writeAsStringSync(_manifest);
  return Project.fromDirectory(fs.directory(path));
}

Future<T> _run<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs, Logger: () => logger}, body: body);

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    logger = BufferLogger();
  });

  test('a node with ten or more versions serves them in numeric order', () {
    final Project project = _projectAt('/notes');
    for (final String version in <String>['v1', 'v2', 'v9', 'v10']) {
      fs.directory('/notes/lib/app/$version').createSync(recursive: true);
    }

    _run(() {
      final Nodes nodes = Nodes.load(project: project);

      expect(nodes.all.single.versions, <String>['v1', 'v2', 'v9', 'v10']);
    });
  });

  test('one stray directory is named in the singular', () {
    final Project project = _projectAt('/notes');
    fs.directory('/notes/lib/app/v1').createSync(recursive: true);
    fs.directory('/notes/lib/orphan').createSync(recursive: true);

    _run(() {
      Nodes.load(project: project);

      expect(logger.warningText, contains('1 directory that no node declares'));
    });
  });

  test('two or more stray directories are named in the plural', () {
    final Project project = _projectAt('/notes');
    fs.directory('/notes/lib/app/v1').createSync(recursive: true);
    fs.directory('/notes/lib/orphan_a').createSync(recursive: true);
    fs.directory('/notes/lib/orphan_b').createSync(recursive: true);

    _run(() {
      Nodes.load(project: project);

      expect(logger.warningText, contains('2 directories that no node declares'));
    });
  });
}
