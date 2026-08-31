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

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/forge/di_wiring.dart';
import 'package:test/test.dart';

late MemoryFileSystem fs;

const String singletonClass =
    'import { Singleton } from "@scribe/alchemy";\n'
    '\n'
    '@Singleton([])\n'
    'class GroundSdkImpl {}\n';

const String manualRegistration =
    'import { container, GroundSdk } from "@scribe/alchemy";\n'
    '\n'
    'container.registerSingleton(GroundSdk, () => GroundSdk.I);\n';

/// Runs [generateDiWiring] and asserts it refused with a message containing [saying].
Future<void> _expectRefusal({required String saying}) async {
  try {
    await _run(generateDiWiring);
    fail('generateDiWiring did not refuse');
  } on ToolExit catch (error) {
    expect(error.message, contains(saying));
  }
}

/// Runs [body] with the fixture file system, unwrapped whether [body] is sync or async.
///
/// `body`'s parameter is `FutureOr<T> Function()` rather than `T Function()`, matching
/// [AppContext.run] exactly: [generateDiWiring] is itself `Future<void> Function()`, and a
/// narrower type here would infer `T` as `Future<void>` instead of `void`, giving back a future
/// of a future whose inner rejection nothing downstream ever awaits.
Future<T> _run<T>(FutureOr<T> Function() body) =>
    AppContext.current.run<T>(overrides: <Type, Generator>{FileSystem: () => fs, Logger: BufferLogger.new}, body: body);

/// Writes the project's `config.yaml`, declaring [sources].
void _project({List<String> sources = const <String>[]}) {
  fs
      .file('/work/notes/config.yaml')
      .writeAsStringSync(
        'name: "notes"\n'
        'dependencies:\n'
        '${sources.isEmpty ? '' : 'sources:\n${sources.map((String name) => '  - $name\n').join()}'}',
      );
}

void _source(String path, String content) {
  fs.file('/work/notes/lib/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

/// Writes a file at the project root, a sibling of `lib/`, whether or not `sources:` covers it.
void _rootSource(String path, String content) {
  fs.file('/work/notes/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

String _generated() => fs.file('/work/notes/.notes/sdk/js/di.ts').readAsStringSync();

void main() {
  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/work/notes/lib').createSync(recursive: true);
    fs.currentDirectory = '/work/notes';
    _project();
  });

  test('a class marked @Singleton is imported for its effect, through the project alias', () async {
    _source('services/ground_sdk.ts', singletonClass);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@app/services/ground_sdk.ts";'));
  });

  test('a project with no @Singleton class gets a file with no import', () async {
    _source('services/plain.ts', 'export class Plain {}\n');

    await _run(generateDiWiring);

    expect(_generated(), isNot(contains('import')));
    expect(_generated(), startsWith('// This file is auto-generated do not edit manually.'));
  });

  test('the imports are sorted, so the file does not churn between runs', () async {
    _source('services/second.ts', singletonClass);
    _source('services/first.ts', singletonClass);

    await _run(generateDiWiring);

    final int first = _generated().indexOf('services/first.ts');
    final int second = _generated().indexOf('services/second.ts');

    expect(first, lessThan(second));
  });

  test('a type-only import of Singleton wires nothing, since it constructs nothing', () async {
    _source('services/typed.ts', 'import type { Singleton } from "@scribe/alchemy";\n');

    await _run(generateDiWiring);

    expect(_generated(), isNot(contains('import "')));
  });

  test('Singleton imported from somewhere else is not read as the marker', () async {
    _source('services/other.ts', 'import { Singleton } from "@app/support/di.ts";\n');

    await _run(generateDiWiring);

    expect(_generated(), isNot(contains('import "@app/services/other.ts";')));
  });

  test('the file says it is generated and names the command that rewrites it', () async {
    await _run(generateDiWiring);

    expect(_generated(), startsWith('// This file is auto-generated do not edit manually.\n// Run: scribe forge\n'));
  });

  test('a file registering something by hand, through container, is imported the same way', () async {
    _source('services/ground_sdk.ts', manualRegistration);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@app/services/ground_sdk.ts";'));
  });

  test('a file marked @Singleton that also reaches for container is imported once, not twice', () async {
    _source('services/both.ts', '$singletonClass$manualRegistration');

    await _run(generateDiWiring);

    expect('import "@app/services/both.ts";'.allMatches(_generated()).length, 1);
  });

  test('container imported from somewhere else is not read as the marker', () async {
    _source('services/other.ts', 'import { container } from "@app/support/di.ts";\n');

    await _run(generateDiWiring);

    expect(_generated(), isNot(contains('import "@app/services/other.ts";')));
  });

  test('a class marked @Singleton under a sources: root is imported through its own alias', () async {
    _project(sources: const <String>['services']);
    _rootSource('services/ground_sdk.ts', singletonClass);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@services/ground_sdk.ts";'));
  });

  test('lib and every sources: root are scanned together', () async {
    _project(sources: const <String>['services', 'jobs']);
    _source('routes/health.ts', singletonClass);
    _rootSource('services/admin.ts', singletonClass);
    _rootSource('jobs/nightly.ts', singletonClass);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@app/routes/health.ts";'));
    expect(_generated(), contains('import "@services/admin.ts";'));
    expect(_generated(), contains('import "@jobs/nightly.ts";'));
  });

  test('the whole project is scanned without any sources: written, lib and beyond', () async {
    _source('routes/health.ts', singletonClass);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@app/routes/health.ts";'));
  });

  test('a file outside lib and outside every sources: root is refused, naming it and the fix', () async {
    _project(sources: const <String>['services']);
    _rootSource('other/forgotten.ts', singletonClass);

    await _expectRefusal(saying: 'other/forgotten.ts');
  });

  test('the refusal names the directory to add under sources:', () async {
    _rootSource('services/ground_sdk.ts', singletonClass);

    await _expectRefusal(saying: '- services');
  });

  test('a project declaring no sources: still resolves everything under lib', () async {
    _project();
    _source('services/ground_sdk.ts', singletonClass);

    await _run(generateDiWiring);

    expect(_generated(), contains('import "@app/services/ground_sdk.ts";'));
  });
}
