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

import 'package:scribe_tools/src/stack/compose.dart';
import 'package:test/test.dart';

const String _running = '{"Service":"api","State":"running","Health":"healthy","ExitCode":0}';
const String _starting = '{"Service":"api","State":"running","Health":"starting","ExitCode":0}';
const String _sick = '{"Service":"api","State":"running","Health":"unhealthy","ExitCode":0}';
const String _plain = '{"Service":"nats","State":"running","Health":"","ExitCode":0}';
const String _ranOnce = '{"Service":"db-migrate","State":"exited","Health":"","ExitCode":0}';
const String _refused = '{"Service":"db-migrate","State":"exited","Health":"","ExitCode":1}';

Map<String, Object?> only(String line) => StackHealth.read(line).single;

void main() {
  group('what Compose wrote', () {
    test('is read one container per line', () {
      expect(StackHealth.read('$_running\n$_ranOnce\n').length, 2);
    });

    test('is read as nothing when Compose wrote nothing', () {
      expect(StackHealth.read('\n  \n'), isEmpty);
    });
  });

  group('a container has settled when', () {
    test('it runs and is healthy', () => expect(StackHealth.hasSettled(only(_running)), isTrue));

    test('it runs and declares no health check', () => expect(StackHealth.hasSettled(only(_plain)), isTrue));

    test('it ran once and left with nothing to say', () => expect(StackHealth.hasSettled(only(_ranOnce)), isTrue));
  });

  group('a container has not settled when', () {
    test('its health check has not answered yet', () => expect(StackHealth.hasSettled(only(_starting)), isFalse));

    test('it left with a status', () => expect(StackHealth.hasSettled(only(_refused)), isFalse));
  });

  group('a container will never settle when', () {
    test('it is unhealthy', () => expect(StackHealth.hasFailed(only(_sick)), isTrue));

    test('it left with a status', () => expect(StackHealth.hasFailed(only(_refused)), isTrue));
  });

  group('a container may still settle when', () {
    test('its health check has not answered yet', () => expect(StackHealth.hasFailed(only(_starting)), isFalse));

    test('it ran once and left with nothing to say', () => expect(StackHealth.hasFailed(only(_ranOnce)), isFalse));
  });
}
