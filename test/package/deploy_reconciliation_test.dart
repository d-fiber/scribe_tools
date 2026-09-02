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
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:test/test.dart';

/// The framework repository, checked out next to this one.
const String _repository = '../scribe';

/// The strings [name] binds to a list literal in `alchemy/package/deploy.ts`.
///
/// Read as text rather than parsed as TypeScript, since Dart has no compiler
/// for it: the two closed lists this file exists to reconcile are exactly the
/// two languages that never talk to each other otherwise.
List<String> _tsList(String source, String name) {
  final RegExp declaration = RegExp('export const $name[^=]*=\\s*(\\[[^\\]]*\\])', multiLine: true);
  final Match? match = declaration.firstMatch(source);
  if (match == null) {
    fail('alchemy/package/deploy.ts declares no $name, or its shape changed enough that this test cannot read it.');
  }

  return RegExp('"([^"]*)"').allMatches(match.group(1)!).map((Match m) => m.group(1)!).toList();
}

void main() {
  final File tsFile = File(p.join(_repository, 'alchemy', 'package', 'deploy.ts'));

  setUpAll(() {
    if (!tsFile.existsSync()) {
      fail('No framework checkout at $_repository. Run this beside a checkout of d-fiber/scribe.');
    }
  });

  group('the closed lists deploy.dart and deploy.ts each carry', () {
    test('name the same database moments', () {
      expect(_tsList(tsFile.readAsStringSync(), 'DATABASE_MOMENTS'), kDatabaseMoments);
    });

    test('require the same database moments', () {
      expect(_tsList(tsFile.readAsStringSync(), 'REQUIRED_DATABASE_MOMENTS'), kRequiredDatabaseMoments);
    });

    test('name the same service fragments', () {
      expect(_tsList(tsFile.readAsStringSync(), 'SERVICE_FRAGMENTS'), kServiceFragments);
    });

    test('name the same deploy entries', () {
      expect(_tsList(tsFile.readAsStringSync(), 'DEPLOY_ENTRIES'), kDeployEntries);
    });
  });
}
