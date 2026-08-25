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

import 'package:scribe_tools/src/package/constraint.dart';
import 'package:test/test.dart';

void main() {
  test('a caret and three numbers is a constraint', () {
    expect(constraintProblem('^1.2.0'), isNull);
  });

  test('three numbers alone is a constraint', () {
    expect(constraintProblem('1.2.0'), isNull);
  });

  test('a range spelled with bounds is refused', () {
    expect(constraintProblem('>=1.0.0 <2.0.0'), contains('is not a constraint'));
  });

  test('a caret on two numbers is refused', () {
    expect(constraintProblem('^1.2'), contains('is not a constraint'));
  });

  test('a caret on something that is not a number is refused', () {
    expect(constraintProblem('^1.x'), contains('is not a constraint'));
  });

  test('a caret accepts the version it names', () {
    expect(allows('^1.2.0', '1.2.0'), isTrue);
  });

  test('a caret accepts a later patch and a later minor', () {
    expect(allows('^1.2.0', '1.2.9'), isTrue);
    expect(allows('^1.2.0', '1.9.0'), isTrue);
  });

  test('a caret stops at the next major', () {
    expect(allows('^1.2.0', '2.0.0'), isFalse);
  });

  test('a caret refuses anything below what it names', () {
    expect(allows('^1.2.0', '1.1.9'), isFalse);
  });

  test('a caret below one stops at the next minor', () {
    expect(allows('^0.1.0', '0.1.9'), isTrue);
    expect(allows('^0.1.0', '0.2.0'), isFalse);
  });

  test('a caret below one tenth stops at the next patch', () {
    expect(allows('^0.0.3', '0.0.3'), isTrue);
    expect(allows('^0.0.3', '0.0.4'), isFalse);
  });

  test('three numbers alone accept that version and no other', () {
    expect(allows('1.2.0', '1.2.0'), isTrue);
    expect(allows('1.2.0', '1.2.1'), isFalse);
  });

  test('a constraint the manifest would refuse answers false instead of throwing', () {
    expect(allows('^1.x', '1.0.0'), isFalse);
    expect(allows('>=1.0.0 <2.0.0', '1.0.0'), isFalse);
  });

  test('a version that is not three numbers is accepted by nothing', () {
    expect(allows('^1.2.0', 'unknown'), isFalse);
  });

  test('the word the checkout answers for is a constraint', () {
    expect(constraintProblem(kAny), isNull);
  });

  test('the word the checkout answers for accepts every version', () {
    expect(allows(kAny, '0.0.1'), isTrue);
    expect(allows(kAny, '9.9.9'), isTrue);
  });

  test('the refusal names the word the checkout answers for, so a reader knows it exists', () {
    expect(constraintProblem('latest'), contains('"$kAny"'));
  });
}
