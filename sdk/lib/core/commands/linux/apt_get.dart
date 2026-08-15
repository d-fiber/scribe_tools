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

import 'dart:io';

import '../../logger.dart';
import '../../process.dart';
import 'fuser.dart';

class AptGet implements ShellCommand {
  @override
  final String executable = 'apt-get';

  final List<String> _tokens = <String>[];

  @override
  List<String> get args => _tokens;

  AptGet update() {
    _tokens.add('update');
    return this;
  }

  AptGet upgrade() {
    _tokens.add('upgrade');
    return this;
  }

  AptGet install() {
    _tokens.add('install');
    return this;
  }

  AptGet yes() {
    _tokens.add('-y');
    return this;
  }

  AptGet package(String name) {
    _tokens.add(name);
    return this;
  }

  static const List<String> _lockFiles = <String>[
    '/var/lib/dpkg/lock-frontend',
    '/var/lib/dpkg/lock',
    '/var/cache/apt/archives/lock',
  ];

  static Future<bool> isLockHeld() async {
    for (final String lockFile in _lockFiles) {
      final ProcessResult result = await capturePrivilegedCommand(
        Fuser()..path(lockFile),
      );
      if (result.exitCode == 0) return true;
    }
    return false;
  }
}

Future<void> runAptGet(Log log, AptGet command) async {
  for (int attempt = 0; attempt < 60; attempt++) {
    final bool held = await AptGet.isLockHeld();
    if (!held) break;
    log.warn('Waiting for apt lock to be released...');
    await Future.delayed(const Duration(seconds: 5));
  }

  await streamPrivilegedCommand(command);
}
