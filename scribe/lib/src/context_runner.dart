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

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/io.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/os.dart';
import 'package:scribe/src/base/platform.dart';
import 'package:scribe/src/base/process.dart';
import 'package:scribe/src/base/template.dart';
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/isolated/scribe_template.dart';
import 'package:scribe/src/globals.dart' as globals;

/// Runs [body] in a context where every dependency has its real implementation.
///
/// This is the one place the concrete classes are named. Everything else asks
/// `globals`. Replacing an entry here, or through [overrides], which wins type
/// by type, changes what the whole run talks to without a call site moving.
Future<T> runInContext<T>(FutureOr<T> Function() body, {Map<Type, Generator>? overrides}) async {
  return AppContext.current.run<T>(
    name: 'global fallbacks',
    body: body,
    overrides: <Type, Generator>{
      Platform: () => const LocalPlatform(),
      ProcessRunner: () => const LocalProcessRunner(),
      OperatingSystemUtils: () => OperatingSystemUtils.forPlatform(platform: globals.platform, fileSystem: globals.fs),
      TemplateRenderer: () => const ScribeTemplateRenderer(),
      Stdio: Stdio.new,
      FileSystem: () => const LocalFileSystem(),
      OutputPreferences: () => OutputPreferences(stdio: globals.stdio, showColor: globals.terminal.supportsColor),
      Terminal: () => AnsiTerminal(stdio: globals.stdio, platform: globals.platform),
      Logger: () => StdoutLogger(
        terminal: globals.terminal,
        stdio: globals.stdio,
        outputPreferences: globals.outputPreferences,
      ),
      ...?overrides,
    },
  );
}
