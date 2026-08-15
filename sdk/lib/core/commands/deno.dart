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

import '../process.dart';

class Deno implements ShellCommand {
  @override
  final String executable = 'deno';

  final List<String> _tokens = <String>[];

  @override
  List<String> get args => _tokens;

  Deno run() {
    _tokens.add('run');
    return this;
  }

  Deno test() {
    _tokens.add('test');
    return this;
  }

  Deno noCheck() {
    _tokens.add('--no-check');
    return this;
  }

  Deno envFile(String path) {
    _tokens.add('--env-file=$path');
    return this;
  }

  Deno allowAll() {
    _tokens.add('--allow-all');
    return this;
  }

  Deno allowNet() {
    _tokens.add('--allow-net');
    return this;
  }

  Deno allowEnv() {
    _tokens.add('--allow-env');
    return this;
  }

  Deno allowRead() {
    _tokens.add('--allow-read');
    return this;
  }

  Deno allowSys() {
    _tokens.add('--allow-sys');
    return this;
  }

  Deno allowWrite() {
    _tokens.add('--allow-write');
    return this;
  }

  Deno allowRun() {
    _tokens.add('--allow-run');
    return this;
  }

  Deno file(String path) {
    _tokens.add(path);
    return this;
  }

  Deno scriptArg(String value) {
    _tokens.add(value);
    return this;
  }
}
