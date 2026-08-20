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

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/os.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/base/template.dart';
import 'package:scribe_tools/src/base/terminal.dart';
import 'package:scribe_tools/src/isolated/scribe_template.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

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
