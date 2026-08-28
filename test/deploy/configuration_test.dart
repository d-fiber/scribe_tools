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
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';
import 'package:test/test.dart';

const String _main = '''
targets:
  local:
    kind: dev

  prod:
    kind: vps
    host: "deploy@203.0.113.10"
    domain: "https://api.notes.example.com"
    dashboard: "https://dash.notes.example.com"
    cors:
      - "https://notes.example.com"
    machine:
      cores: 8
      threads: 16
      memory: 32g
    cpu_cap: true

deploy:
  prod:
    postgres:
      recipe: neon
      region: "eu-central-1"
''';

const String _storage = '''
file_size_limit_mb: 5

deploy:
  prod:
    bucket: external
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

  void write(String name, String source) =>
      fs.file('/work/notes/$configurationDirectoryName/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);

  ProjectConfiguration read() => ProjectConfiguration.load(project: Project.current);

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes').createSync(recursive: true);
    fs.file('/work/notes/config.yaml').writeAsStringSync(
      'name: "notes"\ntargets:\n  legacy:\n    kind: machine\napi:\n  url: "https://legacy.example.com"\n',
    );
  });

  group('a target of a project', () {
    test('carries the host, the domain and the machine its own block declares', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);
        final Target target = read().target('prod');

        expect(target.kind, TargetKind.vps);
        expect(target.host, 'deploy@203.0.113.10');
        expect(target.domain, 'https://api.notes.example.com');
        expect(target.dashboard, 'https://dash.notes.example.com');
        expect(target.cors, <String>['https://notes.example.com']);
        expect(target.machine?.cores, 8);
        expect(target.cpuCap, isTrue);
      });
    });

    test('reads the machine where the stack runs when the block names none', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);

        expect(read().target('local').machine, isNull);
      });
    });

    test('comes from the manifest while the project has no main.yaml yet', () async {
      await inProject(() {
        expect(read().targets.map((Target t) => t.name), <String>['legacy']);
        expect(read().target('legacy').domain, 'https://legacy.example.com');
      });
    });

    test('is refused by naming the ones that exist', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);

        expect(
          () => read().target('staging'),
          throwsA(
            isA<ToolExit>().having(
              (ToolExit e) => e.message,
              'message',
              allOf(contains('staging'), contains('local, prod')),
            ),
          ),
        );
      });
    });

    test('is refused when it deploys onto something that is not a kind', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', 'targets:\n  prod:\n    kind: mainframe\n');

        expect(
          () => read().targets,
          throwsA(isA<ToolExit>().having((ToolExit e) => e.message, 'message', contains('mainframe'))),
        );
      });
    });
  });

  group('where a resource is placed', () {
    test('is a container of the stack when nothing says otherwise', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);

        expect(read().placementOf('local', 'postgres').isContainer, isTrue);
      });
    });

    test('is the recipe main.yaml names, with what that recipe is given', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);
        final Placement placement = read().placementOf('prod', 'postgres');

        expect(placement.recipeName, 'neon');
        expect(placement.params['region'], 'eu-central-1');
        expect(placement.isContainer, isFalse);
      });
    });

    test('is read from the file of the package that owns the resource', () async {
      await inProject(() {
        write('$mainConfigurationName.yaml', _main);
        write('storage.yaml', _storage);

        expect(read().placementOf('prod', 'bucket').isExternal, isTrue);
      });
    });
  });

  group('what a package was configured with', () {
    test('holds the values the project wrote and not where they are deployed', () async {
      await inProject(() {
        write('storage.yaml', _storage);

        expect(read().settingsOf('storage'), <String, Object?>{'file_size_limit_mb': 5});
      });
    });

    test('is empty for a package the project never configured', () async {
      await inProject(() => expect(read().settingsOf('search'), isEmpty));
    });
  });
}
