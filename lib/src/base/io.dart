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
import 'dart:convert';
import 'dart:io' as io;

/// The three standard streams, behind something a test can replace.
class Stdio {
  Stdio();

  /// The bytes arriving on standard input.
  Stream<List<int>> get stdin => io.stdin;

  /// Whether standard output goes to a terminal rather than a pipe or a file.
  bool get hasTerminal => io.stdout.hasTerminal;

  /// Whether standard input comes from a terminal.
  bool get stdinHasTerminal => io.stdin.hasTerminal;

  /// Whether standard input can leave line mode, so a keystroke arrives on its own.
  ///
  /// A terminal is not enough: reading [lineMode] throws when the process has
  /// no controlling terminal, and that is what this answers.
  bool get supportsRawMode {
    if (!io.stdin.hasTerminal) return false;

    try {
      io.stdin.lineMode;
      return true;
    } on Exception {
      return false;
    }
  }

  /// Whether standard input hands over whole lines instead of single keystrokes.
  bool get lineMode => io.stdin.lineMode;

  set lineMode(bool value) => io.stdin.lineMode = value;

  /// Whether what the user types is echoed back by the terminal.
  bool get echoMode => io.stdin.echoMode;

  set echoMode(bool value) => io.stdin.echoMode = value;

  /// The width of the terminal, or [kDefaultTerminalColumns] when there is none.
  int get terminalColumns => hasTerminal ? io.stdout.terminalColumns : kDefaultTerminalColumns;

  /// Writes [message] to standard output, adding nothing to it.
  void write(String message) => io.stdout.write(message);

  /// Writes [message] to standard error, adding nothing to it.
  void writeError(String message) => io.stderr.write(message);
}

/// A [Stdio] that keeps what is written to it and offers nothing to read.
///
/// [output] and [errorOutput] hold what a run produced, which is how a test
/// asserts on what the user would have seen.
class FakeStdio extends Stdio {
  FakeStdio({this.hasTerminalOverride = false, this.terminalColumnsOverride = kDefaultTerminalColumns});

  /// Whether this fake claims to be attached to a terminal.
  final bool hasTerminalOverride;

  /// The width this fake reports.
  final int terminalColumnsOverride;

  /// Everything written to standard output.
  final StringBuffer output = StringBuffer();

  /// Everything written to standard error.
  final StringBuffer errorOutput = StringBuffer();

  @override
  Stream<List<int>> get stdin => const Stream<List<int>>.empty();

  @override
  bool get hasTerminal => hasTerminalOverride;

  @override
  bool get stdinHasTerminal => hasTerminalOverride;

  @override
  bool get supportsRawMode => hasTerminalOverride;

  @override
  bool get lineMode => true;

  @override
  set lineMode(bool value) {}

  @override
  bool get echoMode => true;

  @override
  set echoMode(bool value) {}

  @override
  int get terminalColumns => terminalColumnsOverride;

  @override
  void write(String message) => output.write(message);

  @override
  void writeError(String message) => errorOutput.write(message);
}

/// The width assumed when no terminal reports one.
const int kDefaultTerminalColumns = 100;

/// The keys typed on [stdio], decoded as UTF-8.
///
/// The stream is a broadcast one, so a second prompt in the same run can listen
/// after the first has stopped.
Stream<String> keystrokesOf(Stdio stdio) =>
    stdio.stdin.transform<String>(const Utf8Decoder(allowMalformed: true)).asBroadcastStream();
