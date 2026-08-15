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

part of '../framework.dart';

class Constraints {
  const Constraints({this.minWidth = 0, this.maxWidth, this.minHeight = 0, this.maxHeight});

  const Constraints.tight({required int width, required int height})
    : minWidth = width,
      maxWidth = width,
      minHeight = height,
      maxHeight = height;

  final int minWidth;
  final int? maxWidth;
  final int minHeight;
  final int? maxHeight;

  bool get hasBoundedWidth => maxWidth != null;

  bool get hasBoundedHeight => maxHeight != null;

  Constraints get loose => Constraints(maxWidth: maxWidth, maxHeight: maxHeight);

  Constraints get unboundedHeight => Constraints(minWidth: minWidth, maxWidth: maxWidth);

  Constraints get unboundedWidth => Constraints(minHeight: minHeight, maxHeight: maxHeight);

  Constraints tightenWidth(int width) =>
      Constraints(minWidth: width, maxWidth: width, minHeight: minHeight, maxHeight: maxHeight);

  Constraints tightenHeight(int height) =>
      Constraints(minWidth: minWidth, maxWidth: maxWidth, minHeight: height, maxHeight: height);

  Constraints deflate(int horizontal, int vertical) => Constraints(
    minWidth: _shrink(minWidth, horizontal),
    maxWidth: maxWidth == null ? null : _shrink(maxWidth!, horizontal),
    minHeight: _shrink(minHeight, vertical),
    maxHeight: maxHeight == null ? null : _shrink(maxHeight!, vertical),
  );

  int constrainWidth(int width) => _clamp(width, minWidth, maxWidth);

  int constrainHeight(int height) => _clamp(height, minHeight, maxHeight);

  int _shrink(int value, int by) => value - by < 0 ? 0 : value - by;

  int _clamp(int value, int min, int? max) {
    final int floored = value < min ? min : value;
    return max != null && floored > max ? max : floored;
  }

  @override
  bool operator ==(Object other) =>
      other is Constraints &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight;

  @override
  int get hashCode => Object.hash(minWidth, maxWidth, minHeight, maxHeight);

  @override
  String toString() => 'Constraints(w: $minWidth..$maxWidth, h: $minHeight..$maxHeight)';
}
