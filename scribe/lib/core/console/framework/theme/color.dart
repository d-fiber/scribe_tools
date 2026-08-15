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

final bool _supportsAnsi = _resolveAnsiSupport();

final bool _supportsTrueColor = _colorTerm.contains('truecolor') || _colorTerm.contains('24bit');

final String _colorTerm = Platform.environment['COLORTERM'] ?? '';

bool _resolveAnsiSupport() {
  final Map<String, String> environment = Platform.environment;
  if (environment.containsKey('NO_COLOR')) return false;
  if (environment.containsKey('FORCE_COLOR')) return true;
  return stdout.supportsAnsiEscapes;
}

class Color {
  const Color(this.value);

  const Color.fromARGB(int alpha, int red, int green, int blue)
    : value = ((alpha & 0xff) << 24) | ((red & 0xff) << 16) | ((green & 0xff) << 8) | (blue & 0xff);

  const Color.fromRGB(int red, int green, int blue) : this.fromARGB(0xff, red, green, blue);

  final int value;

  int get alpha => (value >> 24) & 0xff;

  int get red => (value >> 16) & 0xff;

  int get green => (value >> 8) & 0xff;

  int get blue => value & 0xff;

  bool get isTransparent => alpha == 0;

  String get foregroundCode => _sequence(38);

  String get backgroundCode => _sequence(48);

  String paint(String text) => _wrap(text, foregroundCode, 39);

  String fill(String text) => _wrap(text, backgroundCode, 49);

  Color withAlpha(int alpha) => Color.fromARGB(alpha, red, green, blue);

  String _wrap(String text, String open, int close) =>
      isTransparent || !_supportsAnsi ? text : '$open$text$_escape[${close}m';

  String _sequence(int layer) =>
      _supportsTrueColor ? '$_escape[$layer;2;$red;$green;${blue}m' : '$_escape[$layer;5;${_paletteIndex}m';

  int get _paletteIndex {
    if (red == green && green == blue) {
      if (red < 8) return 16;
      if (red > 248) return 231;
      return 232 + (red - 8) * 24 ~/ 247;
    }
    return 16 + 36 * (red * 5 ~/ 255) + 6 * (green * 5 ~/ 255) + blue * 5 ~/ 255;
  }

  @override
  bool operator ==(Object other) => other is Color && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}

abstract final class Colors {
  static const Color transparent = Color(0x00000000);

  static const Color black = Color(0xff000000);
  static const Color red = Color(0xffcd3131);
  static const Color green = Color(0xff0dbc79);
  static const Color yellow = Color(0xffe5e510);
  static const Color blue = Color(0xff2472c8);
  static const Color magenta = Color(0xffbc3fbc);
  static const Color cyan = Color(0xff11a8cd);
  static const Color white = Color(0xffe5e5e5);

  static const Color gray = Color(0xff666666);
  static const Color brightRed = Color(0xfff14c4c);
  static const Color brightGreen = Color(0xff23d18b);
  static const Color brightYellow = Color(0xfff5f543);
  static const Color brightBlue = Color(0xff3b8eea);
  static const Color brightMagenta = Color(0xffd670d6);
  static const Color brightCyan = Color(0xff29b8db);
  static const Color brightWhite = Color(0xffffffff);
}
