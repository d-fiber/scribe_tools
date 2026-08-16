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

import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/io.dart';
import 'package:scribe/src/base/platform.dart';

enum TerminalColor { red, green, blue, cyan, yellow, magenta, grey }

class OutputPreferences {
  OutputPreferences({bool? wrapText, int? wrapColumn, bool? showColor, Stdio? stdio})
    : _stdio = stdio,
      wrapText = wrapText ?? stdio != null,
      _overrideWrapColumn = wrapColumn,
      showColor = showColor ?? false;

  OutputPreferences.test({this.wrapText = false, int wrapColumn = kDefaultTerminalColumns, this.showColor = false})
    : _overrideWrapColumn = wrapColumn,
      _stdio = null;

  final Stdio? _stdio;
  final int? _overrideWrapColumn;

  final bool wrapText;
  final bool showColor;

  int get wrapColumn => _overrideWrapColumn ?? _stdio?.terminalColumns ?? kDefaultTerminalColumns;
}

abstract class Terminal {
  const Terminal();

  bool get supportsColor;

  bool get supportsEmoji;

  bool get isAnimationEnabled;

  bool get stdinHasTerminal;

  bool get supportsRawInput;

  bool get usesTerminalUi;

  set usesTerminalUi(bool value);

  String get successMark;

  String get warningMark;

  String bolden(String message);

  String color(String message, TerminalColor color);

  String clearLines(int count);

  Stream<String> get keystrokes;

  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required void Function(String message) write,
    String? prompt,
    int? defaultChoiceIndex,
  });
}

class AnsiTerminal extends Terminal {
  AnsiTerminal({required this._stdio, required this._platform, this._animationEnabled});

  static const String bold = '\u001B[1m';
  static const String resetAll = '\u001B[0m';
  static const String resetBold = '\u001B[22m';
  static const String resetColor = '\u001B[39m';
  static const String clearLine = '\u001B[2K\r';
  static const String cursorUp = '\u001B[A';

  static const Map<TerminalColor, String> _codes = <TerminalColor, String>{
    TerminalColor.red: '\u001B[31m',
    TerminalColor.green: '\u001B[32m',
    TerminalColor.blue: '\u001B[34m',
    TerminalColor.cyan: '\u001B[36m',
    TerminalColor.yellow: '\u001B[33m',
    TerminalColor.magenta: '\u001B[35m',
    TerminalColor.grey: '\u001B[90m',
  };

  final Stdio _stdio;
  final Platform _platform;
  final bool? _animationEnabled;

  Stream<String>? _keystrokes;
  bool _usesTerminalUi = false;

  @override
  bool get supportsColor => _platform.stdoutSupportsAnsi && !_platform.environment.containsKey('NO_COLOR');

  @override
  bool get supportsEmoji => !_platform.isWindows || _platform.environment.containsKey('WT_SESSION');

  @override
  bool get isAnimationEnabled => _animationEnabled ?? (_stdio.hasTerminal && supportsColor);

  @override
  bool get stdinHasTerminal => _stdio.stdinHasTerminal;

  @override
  bool get supportsRawInput => _stdio.supportsRawMode;

  @override
  bool get usesTerminalUi => _usesTerminalUi;

  @override
  set usesTerminalUi(bool value) => _usesTerminalUi = value;

  @override
  String get successMark => bolden(color(supportsEmoji ? '✓' : '[ok]', TerminalColor.green));

  @override
  String get warningMark => bolden(color(supportsEmoji ? '!' : '[!]', TerminalColor.yellow));

  @override
  String bolden(String message) => supportsColor ? '$bold$message$resetBold' : message;

  @override
  String color(String message, TerminalColor color) => supportsColor ? '${_codes[color]}$message$resetColor' : message;

  @override
  String clearLines(int count) => supportsColor ? '$clearLine${(cursorUp + clearLine) * (count - 1)}' : '';

  @override
  Stream<String> get keystrokes => _keystrokes ??= keystrokesOf(_stdio);

  @override
  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required void Function(String message) write,
    String? prompt,
    int? defaultChoiceIndex,
  }) async {
    if (acceptedCharacters.isEmpty) {
      throwToolExit('promptForCharInput was called without a single accepted answer.');
    }
    if (!usesTerminalUi || !supportsRawInput) {
      throwToolExit('`$prompt` needs an interactive terminal. Pass the value as an option instead.');
    }

    final List<String> choices = <String>[...acceptedCharacters];
    final int? fallback = defaultChoiceIndex;
    if (fallback != null) {
      choices[fallback] = choices[fallback].toUpperCase();
    }

    final String question = '${prompt ?? ''} [${choices.join('|')}]: ';
    final bool restoreLineMode = _stdio.lineMode;
    final bool restoreEchoMode = _stdio.echoMode;

    _stdio.lineMode = false;
    _stdio.echoMode = false;

    try {
      while (true) {
        write(question);
        final String typed = await keystrokes.first;
        final String answer = typed.trim().toLowerCase();

        if (answer.isEmpty && fallback != null) {
          write('${acceptedCharacters[fallback]}\n');
          return acceptedCharacters[fallback];
        }
        if (acceptedCharacters.contains(answer)) {
          write('$answer\n');
          return answer;
        }
        write('\n');
      }
    } finally {
      _stdio.lineMode = restoreLineMode;
      _stdio.echoMode = restoreEchoMode;
    }
  }
}

class TestTerminal extends Terminal {
  TestTerminal({this.supportsColor = false, this.supportsEmoji = false, this.stdinHasTerminal = false});

  @override
  final bool supportsColor;

  @override
  final bool supportsEmoji;

  @override
  final bool stdinHasTerminal;

  @override
  bool get supportsRawInput => stdinHasTerminal;

  @override
  bool get isAnimationEnabled => false;

  @override
  bool usesTerminalUi = false;

  @override
  String get successMark => '[ok]';

  @override
  String get warningMark => '[!]';

  @override
  String bolden(String message) => message;

  @override
  String color(String message, TerminalColor color) => message;

  @override
  String clearLines(int count) => '';

  @override
  Stream<String> get keystrokes => const Stream<String>.empty();

  @override
  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required void Function(String message) write,
    String? prompt,
    int? defaultChoiceIndex,
  }) async => throwToolExit('A test terminal cannot be prompted.');
}
