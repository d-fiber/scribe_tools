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

import 'dart:async';

import '../framework/framework.dart';
import 'test_surface.dart';

List<String> renderToLines(Widget widget, {int width = 80, int? height}) {
  final TestSurface surface = TestSurface(columns: width, viewportHeight: height);
  ConsoleRuntime(surface).render(widget);

  return surface.lines;
}

String renderToText(Widget widget, {int width = 80, int? height}) =>
    renderToLines(widget, width: width, height: height).join('\n');

class ConsoleTester {
  ConsoleTester(Widget app, {int width = 80, int? height, Brightness? brightness})
    : surface = TestSurface(columns: width, viewportHeight: height, brightness: brightness) {
    _result = runConsole<Object?>(app, surface: surface);
  }

  final TestSurface surface;

  late final Future<Object?> _result;

  List<String> get lines => surface.lines;

  String get text => surface.text;

  int get frameCount => surface.frames.length;

  Future<void> pump() async {
    for (int turn = 0; turn < 4; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> sendKey(KeyEvent event) async {
    surface.push(event);
    await pump();
  }

  Future<void> sendControl(ControlCharacter control, {bool shift = false, bool alt = false}) =>
      sendKey(KeyEvent(Key.control(control), shift: shift, alt: alt));

  Future<void> sendChar(String char) => sendKey(KeyEvent(Key.printable(char)));

  Future<void> sendText(String value) async {
    for (final String char in value.split('')) {
      await sendChar(char);
    }
  }

  Future<void> sendMouse({
    required int column,
    required int row,
    MouseButton button = MouseButton.left,
    bool pressed = true,
  }) async {
    surface.push(MouseEvent(button: button, column: column, row: row, pressed: pressed));
    await pump();
  }

  Future<Object?> close() async {
    surface.push(KeyEvent(Key.control(ControlCharacter.ctrlC)));
    return _result;
  }

  Future<Object?> get result => _result;
}
