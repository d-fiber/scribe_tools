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
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/config/declaration_scan.dart';
import 'package:scribe_tools/src/commands/gen/code/generators/config/declarations.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

const String queueDeclaration =
    'import { Queue } from "@scribe/foundation/lib/src/queue/queue.ts";\n'
    'export const emails = new Queue({ name: "emails" }, () => {});\n';

const String cronDeclaration =
    'import { Cron } from "@scribe/foundation/lib/src/cron/cron.ts";\n'
    'export const digest = new Cron({ name: "digest" }, () => {});\n';

const String accountDeclaration =
    'import { Account } from "@scribe/auth/lib/auth.ts";\n'
    'export const user = Account("user", {});\n';

const String searcherDeclaration =
    'import { Field, Search } from "@scribe/search/lib/search.ts";\n'
    'export const stores = Search.on("stores", "store_id");\n';

Matcher throwsToolExit(String saying) =>
    throwsA(isA<ToolExit>().having((ToolExit error) => error.message, 'message', contains(saying)));

Future<T> _run<T>(T Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs, Logger: BufferLogger.new}, body: body);

/// Writes a package into the vendored checkout, opening the buckets of [declarations].
void _package(String name, {Map<String, String> declarations = const <String, String>{}}) {
  final StringBuffer manifest = StringBuffer()
    ..writeln('name: $name')
    ..writeln('version: 1.0.0')
    ..writeln('environment:')
    ..writeln('  scribe: "^1.0.0"');

  if (declarations.isNotEmpty) {
    manifest
      ..writeln('scribe:')
      ..writeln('  declarations:');
    declarations.forEach((String bucket, String marker) => manifest.writeln('    $bucket: $marker'));
  }

  fs.file('/work/notes/scribe/packages/$name/package.yaml')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(manifest.toString());

  fs.file('/work/notes/scribe/packages/$name/deno.json').writeAsStringSync('{}');
}

/// Writes the project's `config.yaml`, mounting [wanted].
void _mount(List<String> wanted) {
  fs
      .file('/work/notes/config.yaml')
      .writeAsStringSync(
        'name: "notes"\n'
        'dependencies:\n'
        '${wanted.map((String name) => '  - $name\n').join()}',
      );
}

void _source(String path, String content) {
  fs.file('/work/notes/lib/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

Future<List<DeclaredKind>> _kinds() => _run(mountedKinds);

Future<Map<String, List<String>>> _scan() async {
  final Map<DeclaredKind, List<String>> found = await _run(
    () => DeclarationScanner.scan(fs.directory('/work/notes/lib'), '/work/notes', mountedKinds()),
  );

  return <String, List<String>>{
    for (final MapEntry<DeclaredKind, List<String>> entry in found.entries) entry.key.bucket: entry.value,
  };
}

String _generated() => fs.file('/work/notes/.notes/sdk/js/declarations.ts').readAsStringSync();

String _bucket(String rendered, String name) =>
    rendered.split('export function ').firstWhere((String part) => part.startsWith('$name('));

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes/lib').createSync(recursive: true);
    fs.currentDirectory = '/work/notes';
    _package('foundation', declarations: <String, String>{'queues': 'Queue', 'crons': 'Cron'});
    _package('auth', declarations: <String, String>{'accounts': 'Account'});
    _package('search', declarations: <String, String>{'searchers': 'Search'});
    _package('storage');
    _mount(const <String>['auth', 'search', 'storage']);
  });

  group('the kinds a project may declare', () {
    test('a mounted package opens the buckets its manifest names', () async {
      expect((await _kinds()).map((DeclaredKind kind) => kind.bucket), <String>[
        'accounts',
        'crons',
        'queues',
        'searchers',
      ]);
    });

    test('a mounted package that opens no bucket contributes none', () async {
      _mount(const <String>['storage']);

      expect((await _kinds()).map((DeclaredKind kind) => kind.bucket), <String>['crons', 'queues']);
    });

    test('a bucket carries the package that opened it and the symbol it marks a file with', () async {
      final DeclaredKind accounts = (await _kinds()).firstWhere((DeclaredKind kind) => kind.bucket == 'accounts');

      expect(accounts.package, 'auth');
      expect(accounts.marker, 'Account');
      expect(accounts.module, '@scribe/auth');
    });

    test('two mounted packages opening one bucket are refused, naming both and the bucket', () async {
      _package('audience', declarations: <String, String>{'accounts': 'Audience'});
      _mount(const <String>['auth', 'audience']);

      await expectLater(_kinds(), throwsToolExit('"auth"'));
      await expectLater(_kinds(), throwsToolExit('"audience"'));
      await expectLater(_kinds(), throwsToolExit('scribe.declarations.accounts'));
    });
  });

  group('the declaration scanner', () {
    test('a project that declares nothing finds nothing, in every bucket its packages opened', () async {
      _source('src/app/index.ts', 'export default () => {};\n');

      final Map<String, List<String>> found = await _scan();

      expect(found.keys, unorderedEquals(<String>['accounts', 'crons', 'queues', 'searchers']));
      expect(found.values.expand((List<String> files) => files), isEmpty);
    });

    test('a file importing Queue from foundation fills the queues bucket and no other', () async {
      _source('jobs/nightly.ts', queueDeclaration);

      final Map<String, List<String>> found = await _scan();

      expect(found['queues'], <String>['lib/jobs/nightly.ts']);
      expect(found['crons'], isEmpty);
      expect(found['accounts'], isEmpty);
      expect(found['searchers'], isEmpty);
    });

    test('a file importing Cron from foundation fills the crons bucket', () async {
      _source('jobs/digest.ts', cronDeclaration);

      expect((await _scan())['crons'], <String>['lib/jobs/digest.ts']);
    });

    test('a file importing Account from auth fills the accounts bucket', () async {
      _source('people/roles.ts', accountDeclaration);

      expect((await _scan())['accounts'], <String>['lib/people/roles.ts']);
    });

    test('a file importing Search from search fills the searchers bucket', () async {
      _source('catalogue/indices.ts', searcherDeclaration);

      expect((await _scan())['searchers'], <String>['lib/catalogue/indices.ts']);
    });

    test('a marker of a package the project does not mount is not read', () async {
      _mount(const <String>['storage']);
      _source('people/roles.ts', accountDeclaration);

      expect((await _scan()).keys, unorderedEquals(<String>['queues', 'crons']));
    });

    test('two files of the same kind are both kept, since both effects are wanted', () async {
      _source('jobs/nightly.ts', queueDeclaration);
      _source('billing/retries.ts', queueDeclaration);

      expect((await _scan())['queues'], <String>['lib/billing/retries.ts', 'lib/jobs/nightly.ts']);
    });

    test('a file declaring a queue and a cron lands in both buckets', () async {
      _source('jobs/both.ts', '$queueDeclaration$cronDeclaration');

      final Map<String, List<String>> found = await _scan();

      expect(found['queues'], <String>['lib/jobs/both.ts']);
      expect(found['crons'], <String>['lib/jobs/both.ts']);
    });

    test('a deep file whose name says nothing is found all the same', () async {
      _source('src/billing/invoices/monthly/_internal/a.ts', queueDeclaration);

      expect((await _scan())['queues'], <String>['lib/src/billing/invoices/monthly/_internal/a.ts']);
    });

    test('the marker is read across a multi-line import clause', () async {
      _source('jobs/wrapped.ts', 'import {\n  Duration,\n  Queue,\n} from "@scribe/foundation";\n');

      expect((await _scan())['queues'], <String>['lib/jobs/wrapped.ts']);
    });

    test('the marker is read through an alias, since the name is read before the as', () async {
      _source('jobs/aliased.ts', 'import { Queue as Q } from "@scribe/foundation";\n');

      expect((await _scan())['queues'], <String>['lib/jobs/aliased.ts']);
    });

    test('a type-only import declares nothing, since it constructs nothing', () async {
      _source('jobs/typed.ts', 'import type { Queue } from "@scribe/foundation";\n');
      _source('jobs/member.ts', 'import { type Cron } from "@scribe/foundation";\n');

      final Map<String, List<String>> found = await _scan();

      expect(found['queues'], isEmpty);
      expect(found['crons'], isEmpty);
    });

    test('a marker imported from somewhere else is not that package declaration', () async {
      _source('jobs/other.ts', 'import { Queue } from "@app/support/queue.ts";\n');
      _source('people/other.ts', 'import { Account } from "@scribe/authority/lib/mod.ts";\n');

      final Map<String, List<String>> found = await _scan();

      expect(found['queues'], isEmpty);
      expect(found['accounts'], isEmpty);
    });

    test('node_modules and hidden directories are never walked', () async {
      _source('node_modules/vendor/queue.ts', queueDeclaration);
      _source('.cache/queue.ts', queueDeclaration);

      expect((await _scan())['queues'], isEmpty);
    });

    test('a file that is not TypeScript is not read', () async {
      _source('jobs/nightly.dart', queueDeclaration);

      expect((await _scan())['queues'], isEmpty);
    });

    test('a project without a lib still answers every bucket its packages opened', () async {
      fs.directory('/work/notes/lib').deleteSync(recursive: true);

      expect((await _scan()).keys, unorderedEquals(<String>['accounts', 'crons', 'queues', 'searchers']));
      expect((await _scan()).values.expand((List<String> files) => files), isEmpty);
    });
  });

  group('the generated loader', () {
    test('one function is written per bucket the mounted packages opened', () async {
      await _run(generateDeclarations);

      for (final String bucket in <String>['queues', 'crons', 'accounts', 'searchers']) {
        expect(_generated(), contains('export function $bucket(): Promise<unknown[]> {'));
      }
    });

    test('a project mounting no package that declares anything gets no function at all', () async {
      _mount(const <String>['storage']);
      _package('foundation');

      await _run(generateDeclarations);

      expect(_generated(), isNot(contains('export function')));
      expect(_generated(), startsWith('// This file is auto-generated do not edit manually.'));
    });

    test('a bucket with no file answers an empty list rather than failing', () async {
      await _run(generateDeclarations);

      expect(_bucket(_generated(), 'crons'), contains('return Promise.all([]);'));
    });

    test('a declaration is imported through the project alias, not by path', () async {
      _source('jobs/nightly.ts', queueDeclaration);

      await _run(generateDeclarations);

      expect(_bucket(_generated(), 'queues'), contains('return Promise.all([import("@app/jobs/nightly.ts")]);'));
      expect(_generated(), isNot(contains('lib/jobs')));
    });

    test('the imports of a bucket are sorted, so the file does not churn between runs', () async {
      _source('jobs/nightly.ts', queueDeclaration);
      _source('billing/retries.ts', queueDeclaration);

      await _run(generateDeclarations);

      expect(
        _bucket(_generated(), 'queues'),
        contains('return Promise.all([import("@app/billing/retries.ts"), import("@app/jobs/nightly.ts")]);'),
      );
    });

    test('the functions are written in one order whatever the packages were mounted in', () async {
      _mount(const <String>['search', 'auth']);

      await _run(generateDeclarations);

      final List<String> written = RegExp(
        r'export function (\w+)\(',
      ).allMatches(_generated()).map((RegExpMatch match) => match.group(1)!).toList();

      expect(written, <String>['accounts', 'crons', 'queues', 'searchers']);
    });

    test('the file says it is generated and names the command that rewrites it', () async {
      await _run(generateDeclarations);

      expect(
        _generated(),
        startsWith('// This file is auto-generated do not edit manually.\n// Run: scribe gen code\n'),
      );
    });
  });
}
