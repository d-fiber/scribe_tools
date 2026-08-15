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

class ConsoleTheme {
  const ConsoleTheme({this.colors = ConsoleColors.dark, this.styles = const ConsoleStyles()});

  static const ConsoleTheme fallback = ConsoleTheme();

  final ConsoleColors colors;
  final ConsoleStyles styles;

  static ConsoleTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Theme>()?.data ?? ConsoleTheme(colors: ConsoleColors.detected);

  ConsoleTheme copyWith({ConsoleColors? colors, ConsoleStyles? styles}) =>
      ConsoleTheme(colors: colors ?? this.colors, styles: styles ?? this.styles);
}

class Theme extends InheritedWidget {
  const Theme({required this.data, required super.child, super.key});

  final ConsoleTheme data;

  @override
  bool updateShouldNotify(Theme previous) =>
      !identical(data.colors, previous.data.colors) || !identical(data.styles, previous.data.styles);
}
