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

class Stdio {
  Stdio();

  Stream<List<int>> get stdin => io.stdin;

  bool get hasTerminal => io.stdout.hasTerminal;

  bool get stdinHasTerminal => io.stdin.hasTerminal;

  bool get supportsRawMode {
    if (!io.stdin.hasTerminal) return false;

    try {
      io.stdin.lineMode;
      return true;
    } on Exception {
      return false;
    }
  }

  bool get lineMode => io.stdin.lineMode;

  set lineMode(bool value) => io.stdin.lineMode = value;

  bool get echoMode => io.stdin.echoMode;

  set echoMode(bool value) => io.stdin.echoMode = value;

  int get terminalColumns => hasTerminal ? io.stdout.terminalColumns : kDefaultTerminalColumns;

  void write(String message) => io.stdout.write(message);

  void writeError(String message) => io.stderr.write(message);
}

class FakeStdio extends Stdio {
  FakeStdio({this.hasTerminalOverride = false, this.terminalColumnsOverride = kDefaultTerminalColumns});

  final bool hasTerminalOverride;
  final int terminalColumnsOverride;

  final StringBuffer output = StringBuffer();
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

const int kDefaultTerminalColumns = 100;

Stream<String> keystrokesOf(Stdio stdio) =>
    stdio.stdin.transform<String>(const Utf8Decoder(allowMalformed: true)).asBroadcastStream();
