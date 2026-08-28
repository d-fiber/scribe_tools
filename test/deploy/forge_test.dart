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
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/forge.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:test/test.dart';

const String _declaration = '''
settings:
  file_size_limit_mb:
    doc: "The largest object the API accepts, in mebibytes."
    type: integer
    default: 100
''';

void main() {
  late MemoryFileSystem fs;

  Future<T> inProject<T>(T Function() body) => AppContext.current.run<T>(
    overrides: <Type, Generator>{FileSystem: () => fs},
    body: () {
      fs.currentDirectory = '/work/notes';

      return body();
    },
  );

  Package package(String name, String declaration) {
    final Directory directory = fs.directory('/work/notes/scribe/packages/$name')..createSync(recursive: true);
    directory.childFile('package.yaml').writeAsStringSync('name: $name\nversion: 1.2.0\n');
    if (declaration.isNotEmpty) directory.childFile(configurationFileName).writeAsStringSync(declaration);

    return Package(name: name, directory: directory);
  }

  Forge forgeOf(List<Package> packages) => Forge(project: Project.current, packages: packages);

  File configured(String name) => fs.file('/work/notes/$configurationDirectoryName/$name.yaml');

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
    fs
        .file('/work/notes/config.yaml')
        .writeAsStringSync(
          'name: "notes"\ntargets:\n  prod:\n    kind: machine\napi:\n  url: "https://notes.example.com"\n',
        );
  });

  group('a forge of a project', () {
    test('writes the file of a package that has none, with the module defaults', () async {
      await inProject(() {
        final ForgeReport report = forgeOf(<Package>[package('storage', _declaration)]).run();

        expect(report.written.map((ForgeEntry e) => e.name), <String>['main', 'storage']);
        expect(configured('storage').readAsStringSync(), contains('file_size_limit_mb: 100'));
        expect(configured('storage').readAsStringSync(), contains('storage 1.2.0'));
      });
    });

    test('rebuilds everything after the whole directory was deleted', () async {
      await inProject(() {
        final List<Package> mounted = <Package>[package('storage', _declaration)];
        forgeOf(mounted).run();
        ProjectConfiguration.directoryOf(Project.current).deleteSync(recursive: true);

        expect(forgeOf(mounted).run().written.length, 2);
        expect(configured('main').existsSync(), isTrue);
        expect(configured('storage').existsSync(), isTrue);
      });
    });

    test('takes the targets of the manifest into the main file it writes', () async {
      await inProject(() {
        forgeOf(const <Package>[]).run();

        expect(configured('main').readAsStringSync(), contains('prod:'));
        expect(configured('main').readAsStringSync(), contains('kind: machine'));
      });
    });

    test('never writes over a file that is already there', () async {
      await inProject(() {
        final List<Package> mounted = <Package>[package('storage', _declaration)];
        forgeOf(mounted).run();
        configured('storage').writeAsStringSync('file_size_limit_mb: 5\n');

        expect(forgeOf(mounted).run().written, isEmpty);
        expect(configured('storage').readAsStringSync(), 'file_size_limit_mb: 5\n');
      });
    });

    test('writes nothing at all when it is only asked to look', () async {
      await inProject(() {
        final ForgeReport report = forgeOf(<Package>[package('storage', _declaration)]).run(write: false);

        expect(report.written.length, 2);
        expect(configured('storage').existsSync(), isFalse);
      });
    });

    test('leaves no file for a package that lets nothing be configured', () async {
      await inProject(() {
        expect(forgeOf(<Package>[package('audience', '')]).run().written.map((ForgeEntry e) => e.name), <String>[
          'main',
        ]);
      });
    });

    test('names a file whose package is no longer a dependency, and keeps it', () async {
      await inProject(() {
        forgeOf(<Package>[package('storage', _declaration)]).run();

        final ForgeReport report = forgeOf(const <Package>[]).run();

        expect(report.orphaned.map((ForgeEntry e) => e.name), <String>['storage']);
        expect(configured('storage').existsSync(), isTrue);
      });
    });
  });

  group('what a forge says about a file it will not touch', () {
    Future<List<String>> problemsOf(String written) => inProject(() {
      final List<Package> mounted = <Package>[package('storage', _declaration)];
      forgeOf(mounted).run();
      configured('storage').writeAsStringSync(written);

      return forgeOf(mounted).run().problems;
    });

    test('names a key the module does not declare, and the ones it does', () async {
      expect(
        await problemsOf('file_size_limit_mb: 5\nfile_size_limit: 5\n'),
        contains(allOf(contains('file_size_limit'), contains('file_size_limit_mb'))),
      );
    });

    test('names a value whose shape is not the one the module declared', () async {
      expect(await problemsOf('file_size_limit_mb: "five"\n'), contains(allOf(contains('integer'), contains('text'))));
    });

    test('names a target nothing declares, and the ones that exist', () async {
      expect(
        await problemsOf('file_size_limit_mb: 5\ndeploy:\n  staging:\n    bucket: external\n'),
        contains(allOf(contains('staging'), contains('prod'))),
      );
    });

    test('names a setting a newer version of the module added, without writing it in', () async {
      await inProject(() {
        final List<Package> mounted = <Package>[package('storage', _declaration)];
        forgeOf(mounted).run();
        configured('storage').writeAsStringSync('deploy: {}\n');

        expect(forgeOf(mounted).run().problems.single, contains('file_size_limit_mb'));
        expect(configured('storage').readAsStringSync(), 'deploy: {}\n');
      });
    });

    test('says nothing about a file that agrees with the module', () async {
      expect(await problemsOf('file_size_limit_mb: 5\ndeploy:\n  prod:\n    bucket: external\n'), isEmpty);
    });
  });
}
