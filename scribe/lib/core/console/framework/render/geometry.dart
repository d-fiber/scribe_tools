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

class Offset {
  const Offset(this.x, this.y);

  static const Offset zero = Offset(0, 0);

  final int x;
  final int y;

  Offset shifted(int dx, int dy) => Offset(x + dx, y + dy);

  @override
  bool operator ==(Object other) => other is Offset && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Offset($x, $y)';
}

class Rect {
  const Rect({required this.left, required this.top, required this.width, required this.height});

  static const Rect zero = Rect(left: 0, top: 0, width: 0, height: 0);

  final int left;
  final int top;
  final int width;
  final int height;

  bool get isEmpty => width <= 0 || height <= 0;

  int get right => left + width;

  int get bottom => top + height;

  Rect shifted(int dx, int dy) => Rect(left: left + dx, top: top + dy, width: width, height: height);

  Rect resized(int width, int height) => Rect(left: left, top: top, width: width, height: height);

  bool contains(int x, int y) => !isEmpty && x >= left && x < right && y >= top && y < bottom;

  @override
  bool operator ==(Object other) =>
      other is Rect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'Rect($left, $top, ${width}x$height)';
}
