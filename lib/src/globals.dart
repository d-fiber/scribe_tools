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

/// Everything that touches the world, read from the context the zone carries.
///
/// Nothing here is a singleton. Each getter asks [AppContext] first and only
/// falls back to a real implementation when nothing was registered, so a run
/// wrapped in a context with overrides sees its own file system, logger and
/// process runner without a single call site changing.
///
/// The fallbacks are there for code reached outside any context; the ones that
/// cost something to build are kept, so a run never builds two of them.
library;

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
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/shell.dart';
import 'package:scribe_tools/src/tools.dart';

/// The context the current zone carries.
AppContext get context => AppContext.current;

const Platform _defaultPlatform = LocalPlatform();

/// The system this run is happening on.
Platform get platform => context.get<Platform>() ?? _defaultPlatform;

Stdio? _stdioInstance;

/// The standard streams this run reads and writes.
Stdio get stdio => context.get<Stdio>() ?? (_stdioInstance ??= Stdio());

const FileSystem _defaultFileSystem = LocalFileSystem();

/// The file system every path in this run is opened on.
FileSystem get fs => context.get<FileSystem>() ?? _defaultFileSystem;

OutputPreferences? _outputPreferencesInstance;

/// What the user asked this run's output to look like.
OutputPreferences get outputPreferences =>
    context.get<OutputPreferences>() ??
    (_outputPreferencesInstance ??= OutputPreferences(stdio: stdio, showColor: true));

Terminal? _terminalInstance;

/// What the terminal this run writes to is capable of.
Terminal get terminal =>
    context.get<Terminal>() ?? (_terminalInstance ??= AnsiTerminal(stdio: stdio, platform: platform));

Logger? _loggerInstance;

/// Everything this run prints.
Logger get logger =>
    context.get<Logger>() ??
    (_loggerInstance ??= StdoutLogger(terminal: terminal, stdio: stdio, outputPreferences: outputPreferences));

/// The project the current directory is the root of.
///
/// Throws a `ToolExit` when it is not one, unless a project was put in the
/// context. Every command that needs a project has already been refused by then.
Project get project => context.get<Project>() ?? Project.current;

/// The engine that fills the templates this run writes from.
TemplateRenderer get templateRenderer => context.get<TemplateRenderer>() ?? const ScribeTemplateRenderer();

OperatingSystemUtils? _osInstance;

/// What this run knows about the host beyond files and processes.
OperatingSystemUtils get os =>
    context.get<OperatingSystemUtils>() ??
    (_osInstance ??= OperatingSystemUtils.forPlatform(platform: platform, fileSystem: fs));

const ProcessRunner _defaultProcessRunner = LocalProcessRunner();

/// How this run starts external commands.
ProcessRunner get processRunner => context.get<ProcessRunner>() ?? _defaultProcessRunner;

/// The shell the user came from, and where its profile lives.
Shell get shell => context.get<Shell>() ?? Shell.detect(platform: platform, fileSystem: fs);

const ToolProvisioner _defaultProvisioner = ToolProvisioner();

/// The external tools this run can look for and offer to install.
ToolProvisioner get tools => context.get<ToolProvisioner>() ?? _defaultProvisioner;
