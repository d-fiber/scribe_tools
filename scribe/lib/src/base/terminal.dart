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

/// A colour a message can be written in.
enum TerminalColor { red, green, blue, cyan, yellow, magenta, grey }

/// What the user asked the output to look like.
///
/// This is the wish, not the capability: [showColor] carries `--color`, while
/// [Terminal.supportsColor] says whether the escape codes would be understood
/// at all. A logger needs both to agree before it paints anything.
class OutputPreferences {
  OutputPreferences({bool? wrapText, int? wrapColumn, bool? showColor, Stdio? stdio})
    : _stdio = stdio,
      wrapText = wrapText ?? stdio != null,
      _overrideWrapColumn = wrapColumn,
      showColor = showColor ?? false;

  /// Creates preferences with fixed values, so a test never reads a real terminal.
  OutputPreferences.test({this.wrapText = false, int wrapColumn = kDefaultTerminalColumns, this.showColor = false})
    : _overrideWrapColumn = wrapColumn,
      _stdio = null;

  final Stdio? _stdio;
  final int? _overrideWrapColumn;

  /// Whether long lines are broken to fit [wrapColumn].
  final bool wrapText;

  /// Whether colour is wanted.
  final bool showColor;

  /// The column long lines are broken at.
  ///
  /// The terminal's own width when nothing overrides it, and
  /// [kDefaultTerminalColumns] when there is no terminal to ask.
  int get wrapColumn => _overrideWrapColumn ?? _stdio?.terminalColumns ?? kDefaultTerminalColumns;
}

/// What the terminal can do, and the escape codes that do it.
abstract class Terminal {
  const Terminal();

  /// Whether ANSI colour is rendered rather than shown as escape codes.
  bool get supportsColor;

  /// Whether characters outside ASCII can be trusted to the font.
  bool get supportsEmoji;

  /// Whether a line may be redrawn in place.
  bool get isAnimationEnabled;

  /// Whether there is a terminal to read from.
  bool get stdinHasTerminal;

  /// Whether a single keystroke can be read without waiting for a newline.
  bool get supportsRawInput;

  /// Whether the code running now is allowed to ask the user a question.
  ///
  /// False until the runner has parsed the global options, so nothing prompts
  /// before `--yes` has been read.
  bool get usesTerminalUi;

  set usesTerminalUi(bool value);

  /// The mark that closes a step that succeeded.
  String get successMark;

  /// The mark that closes a step the user should look at.
  String get warningMark;

  /// The mark that opens something that is missing or does not work.
  String get errorMark;

  /// [message] wrapped in the codes that embolden it, or unchanged when colour is off.
  String bolden(String message);

  /// [message] wrapped in the codes that paint it, or unchanged when colour is off.
  String color(String message, TerminalColor color);

  /// The escape sequence that erases [count] lines, the one holding the cursor first.
  String clearLines(int count);

  /// The keys typed by the user.
  Stream<String> get keystrokes;

  /// Asks [prompt] until the answer is one of [acceptedCharacters], and returns it.
  ///
  /// The answer is lowercased and trimmed before it is compared. An empty
  /// answer picks [acceptedCharacters] at [defaultChoiceIndex] when one is
  /// given, and is refused otherwise. The question goes out through [write]
  /// rather than to a stream, so it takes the same path as every other message.
  ///
  /// Throws a [ToolExit] when there is no terminal to ask on, or when the
  /// caller is not allowed to prompt: the value has to arrive as an option.
  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required void Function(String message) write,
    String? prompt,
    int? defaultChoiceIndex,
  });
}

/// The [Terminal] of a real terminal that speaks ANSI.
class AnsiTerminal extends Terminal {
  AnsiTerminal({required this._stdio, required this._platform, this._animationEnabled});

  /// Opens bold text.
  static const String bold = '\u001B[1m';

  /// Drops every attribute at once, colour and weight together.
  static const String resetAll = '\u001B[0m';

  /// Closes [bold] without touching the colour.
  static const String resetBold = '\u001B[22m';

  /// Returns to the default colour without touching the weight.
  static const String resetColor = '\u001B[39m';

  /// Empties the line the cursor is on, and puts the cursor back at its start.
  static const String clearLine = '\u001B[2K\r';

  /// Moves the cursor up one line, leaving its column alone.
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

  /// Whether the stream takes ANSI and `NO_COLOR` is unset, as the convention asks.
  @override
  bool get supportsColor => _platform.stdoutSupportsAnsi && !_platform.environment.containsKey('NO_COLOR');

  /// Whether the console renders emoji, which outside Windows is assumed.
  ///
  /// The Windows console only does inside Windows Terminal, which announces
  /// itself with `WT_SESSION`.
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
  String get errorMark => bolden(color(supportsEmoji ? '✗' : '[x]', TerminalColor.red));

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

/// A [Terminal] with no colour, no animation and no answer to give.
///
/// [promptForCharInput] always throws: a test that reaches a prompt has found a
/// path that would have waited for a human forever.
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
  String get errorMark => '[x]';

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
