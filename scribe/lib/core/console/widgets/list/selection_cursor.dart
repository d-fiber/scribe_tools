// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

class SelectionCursor {
  const SelectionCursor({this.index = 0, this.offset = 0});

  final int index;
  final int offset;

  SelectionCursor clamped({required int length, required int height}) {
    if (length <= 0) return const SelectionCursor();
    return _at(index.clamp(0, length - 1), length: length, height: height);
  }

  SelectionCursor moveBy(int step, {required int length, required int height, bool wrap = true}) {
    if (length <= 0 || step == 0) return clamped(length: length, height: height);

    final int current = index.clamp(0, length - 1);
    final int target = wrap ? (current + step + length * step.abs()) % length : (current + step).clamp(0, length - 1);

    return _at(target, length: length, height: height);
  }

  SelectionCursor moveTo(int target, {required int length, required int height}) =>
      length <= 0 ? const SelectionCursor() : _at(target.clamp(0, length - 1), length: length, height: height);

  SelectionCursor first({required int length, required int height}) => moveTo(0, length: length, height: height);

  SelectionCursor last({required int length, required int height}) =>
      moveTo(length - 1, length: length, height: height);

  SelectionCursor page(int direction, {required int length, required int height}) =>
      moveBy(direction * height, length: length, height: height, wrap: false);

  SelectionCursor _at(int target, {required int length, required int height}) => SelectionCursor(
    index: target,
    offset: scrolled(offset: offset, selected: target, count: length, height: height),
  );

  static int scrolled({required int offset, required int selected, required int count, required int height}) {
    int start = offset;
    if (selected < start) start = selected;
    if (selected >= start + height) start = selected - height + 1;

    return start.clamp(0, (count - height).clamp(0, count));
  }
}
