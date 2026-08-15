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

enum Brightness { dark, light }

final RegExp _rgbReply = RegExp(r'rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)');

Brightness? brightnessFromReply(String reply) {
  final RegExpMatch? match = _rgbReply.firstMatch(reply);
  if (match == null) return null;

  final int red = _channel(match.group(1)!);
  final int green = _channel(match.group(2)!);
  final int blue = _channel(match.group(3)!);
  final double luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255;

  return luminance > 0.5 ? Brightness.light : Brightness.dark;
}

int _channel(String hex) {
  final int value = int.parse(hex, radix: 16);
  return hex.length <= 2 ? value : value >> 4 * (hex.length - 2);
}

Brightness? brightnessFromNotification(String report) {
  if (!report.startsWith('997;')) return null;

  return switch (report.substring(4)) {
    '1' => Brightness.dark,
    '2' => Brightness.light,
    _ => null,
  };
}

Brightness? brightnessFromEnvironment() {
  final String? pair = Platform.environment['COLORFGBG'];
  if (pair == null) return null;

  final int? background = int.tryParse(pair.split(';').last);
  if (background == null) return null;

  return background == 7 || background > 8 ? Brightness.light : Brightness.dark;
}

class BackgroundColors {
  const BackgroundColors({this.primary = Colors.transparent, this.secondary = Colors.transparent});

  final Color primary;
  final Color secondary;
}

class TextColors {
  const TextColors({
    this.primary = const Color(0xfff1f2f4),
    this.secondary = const Color(0xffb5b6b7),
    this.tertiary = const Color(0xff7d7d80),
    this.placeholder = const Color(0xff5a5960),
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color placeholder;
}

class ActionColors {
  const ActionColors({
    this.primary = const Color(0xfffa062b),
    this.onPrimary = const Color(0xffffffff),
    this.link = const Color(0xff1680d1),
    this.highlight = const Color(0xff901929),
  });

  final Color primary;
  final Color onPrimary;
  final Color link;
  final Color highlight;
}

class FeedbackColors {
  const FeedbackColors({
    this.error = const Color(0xffe34f45),
    this.success = const Color(0xff34c175),
    this.warning = const Color(0xfffd7f2b),
    this.info = const Color(0xff5ac8fa),
  });

  final Color error;
  final Color success;
  final Color warning;
  final Color info;
}

class OutlineColors {
  const OutlineColors({this.border = const Color(0xff40403d), this.separator = const Color(0xff40403d)});

  final Color border;
  final Color separator;
}

class NavigationColors {
  const NavigationColors({
    this.topBar = const Color(0xff2e2e2b),
    this.panel = const Color(0xff2e2e2b),
    this.bottomBar = const Color(0xff2e2e2b),
  });

  final Color topBar;
  final Color panel;
  final Color bottomBar;
}

class SurfaceColors {
  const SurfaceColors({
    this.section = const Color(0xff2e2e2b),
    this.fill = const Color(0xff3f3f3d),
    this.inactive = const Color(0xffbbbcc1),
  });

  final Color section;
  final Color fill;
  final Color inactive;
}

class ConsoleColors {
  const ConsoleColors({
    this.brightness = Brightness.dark,
    this.background = const BackgroundColors(),
    this.text = const TextColors(),
    this.action = const ActionColors(),
    this.feedback = const FeedbackColors(),
    this.outline = const OutlineColors(),
    this.navigation = const NavigationColors(),
    this.surface = const SurfaceColors(),
  });

  static const ConsoleColors dark = ConsoleColors();

  static const ConsoleColors light = ConsoleColors(
    brightness: Brightness.light,
    text: TextColors(
      primary: Color(0xff1c1c1e),
      secondary: Color(0xff4a4a4f),
      tertiary: Color(0xff8a8a8f),
      placeholder: Color(0xffaaaab0),
    ),
    action: ActionColors(
      primary: Color(0xffd1001f),
      onPrimary: Color(0xffffffff),
      link: Color(0xff0b5fa5),
      highlight: Color(0xffffd5db),
    ),
    feedback: FeedbackColors(
      error: Color(0xffc22b22),
      success: Color(0xff1e8e52),
      warning: Color(0xffb35a12),
      info: Color(0xff0a7aaf),
    ),
    outline: OutlineColors(border: Color(0xffd4d4d0), separator: Color(0xffd4d4d0)),
    navigation: NavigationColors(topBar: Color(0xfff2f2ef), panel: Color(0xfff2f2ef), bottomBar: Color(0xfff2f2ef)),
    surface: SurfaceColors(section: Color(0xfff2f2ef), fill: Color(0xffe6e6e2), inactive: Color(0xff9a9aa0)),
  );

  final Brightness brightness;
  final BackgroundColors background;
  final TextColors text;
  final ActionColors action;
  final FeedbackColors feedback;
  final OutlineColors outline;
  final NavigationColors navigation;
  final SurfaceColors surface;

  static final ConsoleColors detected = forBrightness(brightnessFromEnvironment() ?? Brightness.dark);

  static ConsoleColors forBrightness(Brightness brightness) => brightness == Brightness.light ? light : dark;

  static Color fromHex(String hex) {
    String value = hex.replaceAll('#', '').toUpperCase();
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  }
}
