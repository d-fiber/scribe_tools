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
import 'package:scribe_tools/src/deploy/settings.dart';
import 'package:test/test.dart';

const String _declaration = '''
settings:
  file_size_limit_mb:
    doc: "The largest object the API accepts, in mebibytes."
    type: integer
    default: 100

  image_transformation:
    doc: "Whether an image may be asked for at another size."
    type: boolean
    default: true

requires:
  - name: objects
    type: bucket
''';

void main() {
  late FileSystem fs;

  File declare(String source) => fs.file('configuration.yaml')..writeAsStringSync(source);

  setUp(() => fs = MemoryFileSystem.test());

  group('what a package lets a project configure', () {
    test('is read in declaration order, with its documentation and its default', () {
      final List<Setting> settings = Settings.read(declare(_declaration)).settings;

      expect(settings.map((Setting s) => s.name), <String>['file_size_limit_mb', 'image_transformation']);
      expect(settings.first.type, 'integer');
      expect(settings.first.defaultValue, 100);
      expect(settings.last.doc, 'Whether an image may be asked for at another size.');
    });

    test('is empty for a package that declares only the resources it needs', () {
      expect(Settings.read(declare('requires:\n  - name: objects\n    type: bucket\n')).isEmpty, isTrue);
    });

    test('is empty for a package that declares nothing at all', () {
      expect(Settings.read(fs.file('absent.yaml')).isEmpty, isTrue);
    });

    test('scaffolds a file carrying every default under the sentence that explains it', () {
      final String written = Settings.read(declare(_declaration)).scaffold(module: 'storage', version: '1.0.0');

      expect(written, contains('# The largest object the API accepts, in mebibytes.\nfile_size_limit_mb: 100'));
      expect(written, contains('image_transformation: true'));
      expect(written, contains('$deployKey: {}'));
      expect(written, contains('`scribe forge` never'));
    });

    test('is refused when a setting names a type nothing scaffolds', () {
      expect(
        () => Settings.read(declare('settings:\n  size:\n    doc: "d"\n    type: decimal\n    default: 1\n')),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('decimal'))),
      );
    });

    test('is refused when a setting says nothing about what it decides', () {
      expect(
        () => Settings.read(declare('settings:\n  size:\n    type: integer\n    default: 1\n')),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('doc'))),
      );
    });

    test('is refused when a setting gives a project no default to start from', () {
      expect(
        () => Settings.read(declare('settings:\n  size:\n    doc: "d"\n    type: integer\n')),
        throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('default'))),
      );
    });
  });
}
