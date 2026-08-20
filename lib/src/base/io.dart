// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

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
