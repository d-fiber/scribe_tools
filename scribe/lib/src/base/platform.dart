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

import 'dart:io' as io;

abstract class Platform {
  const Platform();

  String get operatingSystem;

  Map<String, String> get environment;

  String get pathSeparator;

  bool get stdoutSupportsAnsi;

  String get version;

  bool get isWindows => operatingSystem == 'windows';

  bool get isMacOS => operatingSystem == 'macos';

  bool get isLinux => operatingSystem == 'linux';
}

class LocalPlatform extends Platform {
  const LocalPlatform();

  @override
  String get operatingSystem => io.Platform.operatingSystem;

  @override
  Map<String, String> get environment => io.Platform.environment;

  @override
  String get pathSeparator => io.Platform.pathSeparator;

  @override
  bool get stdoutSupportsAnsi => io.stdout.supportsAnsiEscapes;

  @override
  String get version => io.Platform.version;
}

class FakePlatform extends Platform {
  const FakePlatform({
    this.operatingSystem = 'macos',
    this.environment = const <String, String>{},
    this.pathSeparator = '/',
    this.stdoutSupportsAnsi = false,
    this.version = 'test',
  });

  @override
  final String operatingSystem;

  @override
  final Map<String, String> environment;

  @override
  final String pathSeparator;

  @override
  final bool stdoutSupportsAnsi;

  @override
  final String version;
}
