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

enum MouseButton { left, middle, right, wheelUp, wheelDown, none }

sealed class ConsoleEvent {
  const ConsoleEvent();
}

class KeyEvent extends ConsoleEvent {
  const KeyEvent(this.key, {this.alt = false, this.shift = false});

  final Key key;
  final bool alt;
  final bool shift;

  ControlCharacter get control => key.controlChar;

  bool get isControl => key.isControl;

  String get char => key.char;

  @override
  String toString() {
    final String name = key.isControl ? key.controlChar.name : key.char;
    return 'KeyEvent(${alt ? 'alt+' : ''}${shift ? 'shift+' : ''}$name)';
  }
}

class MouseEvent extends ConsoleEvent {
  const MouseEvent({
    required this.button,
    required this.column,
    required this.row,
    required this.pressed,
    this.motion = false,
  });

  final MouseButton button;
  final int column;
  final int row;
  final bool pressed;
  final bool motion;

  bool get isWheel => button == MouseButton.wheelUp || button == MouseButton.wheelDown;

  MouseEvent at({required int column, required int row}) =>
      MouseEvent(button: button, column: column, row: row, pressed: pressed, motion: motion);

  @override
  String toString() => 'MouseEvent($button, $column:$row, pressed: $pressed, motion: $motion)';
}

MouseEvent? mouseFromReport(String report, {required bool pressed}) {
  final List<String> parts = report.split(';');
  if (parts.length != 3) return null;

  final int? code = int.tryParse(parts[0]);
  final int? column = int.tryParse(parts[1]);
  final int? row = int.tryParse(parts[2]);
  if (code == null || column == null || row == null) return null;

  return MouseEvent(button: _buttonFromCode(code), column: column, row: row, pressed: pressed, motion: code & 32 != 0);
}

MouseButton _buttonFromCode(int code) {
  if (code & 64 != 0) return code & 1 == 0 ? MouseButton.wheelUp : MouseButton.wheelDown;

  return switch (code & 3) {
    0 => MouseButton.left,
    1 => MouseButton.middle,
    2 => MouseButton.right,
    _ => MouseButton.none,
  };
}
