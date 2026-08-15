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

final RegExp _ansi = RegExp('$_escape\\[[0-9;]*m');

int runeWidth(int rune) {
  if (rune == 0x200d || rune == 0xfe0f || rune == 0x00ad) return 0;
  if (rune >= 0x0300 && rune <= 0x036f) return 0;
  if (rune >= 0x1ab0 && rune <= 0x1aff) return 0;
  if (rune >= 0x20d0 && rune <= 0x20ff) return 0;
  if (rune >= 0xfe20 && rune <= 0xfe2f) return 0;
  if (rune < 0x1100) return 1;

  const List<List<int>> wide = <List<int>>[
    <int>[0x1100, 0x115f],
    <int>[0x2e80, 0x303e],
    <int>[0x3041, 0x33ff],
    <int>[0x3400, 0x4dbf],
    <int>[0x4e00, 0x9fff],
    <int>[0xa000, 0xa4cf],
    <int>[0xac00, 0xd7a3],
    <int>[0xf900, 0xfaff],
    <int>[0xfe30, 0xfe4f],
    <int>[0xff00, 0xff60],
    <int>[0xffe0, 0xffe6],
    <int>[0x1f300, 0x1f64f],
    <int>[0x1f900, 0x1f9ff],
    <int>[0x1fa70, 0x1faff],
    <int>[0x20000, 0x3fffd],
  ];

  for (final List<int> range in wide) {
    if (rune >= range[0] && rune <= range[1]) return 2;
  }
  return 1;
}

String stripAnsi(String text) => text.replaceAll(_ansi, '');

int visibleWidth(String text) {
  final String stripped = stripAnsi(text);
  int width = 0;
  for (final int rune in stripped.runes) {
    width += runeWidth(rune);
  }
  return width;
}

String padVisible(String text, int width) {
  final int missing = width - visibleWidth(text);
  return missing <= 0 ? text : text + ' ' * missing;
}

class Frame {
  const Frame(this.lines);

  const Frame.empty() : lines = const <String>[];

  Frame.text(String value) : lines = value.split('\n');

  final List<String> lines;

  int get height => lines.length;

  int get width => lines.fold(0, (int widest, String line) {
    final int current = visibleWidth(line);
    return current > widest ? current : widest;
  });

  Frame padded(int width) => Frame(<String>[for (final String line in lines) padVisible(line, width)]);

  static Frame stack(List<Frame> frames) => Frame(<String>[for (final Frame frame in frames) ...frame.lines]);

  static Frame beside(List<Frame> frames) {
    final List<Frame> blocks = <Frame>[for (final Frame frame in frames) frame.padded(frame.width)];
    final int height = blocks.fold(0, (int tallest, Frame block) => block.height > tallest ? block.height : tallest);
    return Frame(<String>[
      for (int row = 0; row < height; row++)
        blocks.map((Frame block) => row < block.height ? block.lines[row] : ' ' * block.width).join(),
    ]);
  }
}
