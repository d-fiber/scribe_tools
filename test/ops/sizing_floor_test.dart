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

import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/ops/capacity.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing_rules.dart';
import 'package:test/test.dart';

import 'capacity_source.dart';

const ServiceCapacity _db = ServiceCapacity(
  name: 'db',
  weight: 950,
  runtime: 'postgres',
  minMib: 256,
  devMib: 1024,
  cpuShares: 4096,
);

const ServiceCapacity _redis = ServiceCapacity(
  name: 'redis',
  weight: 50,
  runtime: 'redis',
  minMib: 1024,
  devMib: 1024,
  cpuShares: 2048,
);

Map<String, String> _resolve(Hardware hardware) =>
    SizingRules(hardware, Capacity(<ServiceCapacity>[_db, _redis])).resolve();

void main() {
  group('the floor a capacity file declares under "min"', () {
    test('is what a service gets when its share of the budget falls under it', () {
      expect(
        _resolve(const Hardware(cores: 4, threads: 8, memoryGb: 8))['redis_mem_limit'],
        '1g',
        reason: 'a share of 328 MiB is under the 1024 MiB redis declares it needs to hold its keys',
      );
    });

    test('is not what a service gets when its share of the budget clears it', () {
      expect(
        _resolve(const Hardware(cores: 4, threads: 8, memoryGb: 8))['db_mem_limit'],
        '6.08g',
        reason: 'db asks for 256 MiB and its share hands it 6226, so the floor decides nothing',
      );
    });

    test('is what a derived setting is computed from once it has won', () {
      expect(
        _resolve(const Hardware(cores: 4, threads: 8, memoryGb: 8))['redis_maxmemory'],
        '512mb',
        reason: 'maxmemory is half the limit, and the limit is the floor rather than the raw share',
      );
    });

    test('refuses the render when the floors of the services that start do not fit the budget', () {
      expect(
        () => _resolve(const Hardware(cores: 1, threads: 2, memoryGb: 1)),
        throwsA(
          isA<ToolExit>().having(
            (ToolExit exit) => exit.message,
            'message',
            allOf(contains('1 c / 2 t, 1 Go'), contains('1280'), contains('461')),
          ),
        ),
      );
    });

    test('refuses a two gibibyte machine that mounts every package of the framework', () {
      expect(
        () => SizingRules(const Hardware(cores: 1, threads: 2, memoryGb: 2), frameworkCapacity()).resolve(),
        throwsA(isA<ToolExit>().having((ToolExit exit) => exit.message, 'message', contains('1824'))),
      );
    });
  });
}
