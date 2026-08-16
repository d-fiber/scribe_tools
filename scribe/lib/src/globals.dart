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

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:scribe/src/base/context.dart';
import 'package:scribe/src/base/io.dart';
import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/os.dart';
import 'package:scribe/src/base/process.dart';
import 'package:scribe/src/base/platform.dart';
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/base/template.dart';
import 'package:scribe/src/isolated/scribe_template.dart';
import 'package:scribe/src/project.dart';
import 'package:scribe/src/shell.dart';
import 'package:scribe/src/tools.dart';

AppContext get context => AppContext.current;

const Platform _defaultPlatform = LocalPlatform();

Platform get platform => context.get<Platform>() ?? _defaultPlatform;

Stdio? _stdioInstance;

Stdio get stdio => context.get<Stdio>() ?? (_stdioInstance ??= Stdio());

const FileSystem _defaultFileSystem = LocalFileSystem();

FileSystem get fs => context.get<FileSystem>() ?? _defaultFileSystem;

OutputPreferences? _outputPreferencesInstance;

OutputPreferences get outputPreferences =>
    context.get<OutputPreferences>() ?? (_outputPreferencesInstance ??= OutputPreferences(stdio: stdio, showColor: true));

Terminal? _terminalInstance;

Terminal get terminal =>
    context.get<Terminal>() ?? (_terminalInstance ??= AnsiTerminal(stdio: stdio, platform: platform));

Logger? _loggerInstance;

Logger get logger =>
    context.get<Logger>() ??
    (_loggerInstance ??= StdoutLogger(terminal: terminal, stdio: stdio, outputPreferences: outputPreferences));

Project get project => context.get<Project>() ?? Project.current;

TemplateRenderer get templateRenderer => context.get<TemplateRenderer>() ?? const ScribeTemplateRenderer();

OperatingSystemUtils? _osInstance;

OperatingSystemUtils get os =>
    context.get<OperatingSystemUtils>() ??
    (_osInstance ??= OperatingSystemUtils.forPlatform(platform: platform, fileSystem: fs));

const ProcessRunner _defaultProcessRunner = LocalProcessRunner();

ProcessRunner get processRunner => context.get<ProcessRunner>() ?? _defaultProcessRunner;

Shell get shell => context.get<Shell>() ?? Shell.detect(platform: platform, fileSystem: fs);

const ToolProvisioner _defaultProvisioner = ToolProvisioner();

ToolProvisioner get tools => context.get<ToolProvisioner>() ?? _defaultProvisioner;
