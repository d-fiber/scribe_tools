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

import '../../process.dart';

class PgDump implements ShellCommand {
  @override
  final String executable = 'pg_dump';

  final List<String> _tokens = <String>[];

  @override
  List<String> get args => _tokens;

  PgDump user(String name) {
    _tokens
      ..add('-U')
      ..add(name);
    return this;
  }

  PgDump noPassword() {
    _tokens.add('--no-password');
    return this;
  }

  PgDump rolesOnly() {
    _tokens.add('--roles-only');
    return this;
  }

  PgDump noRolePasswords() {
    _tokens.add('--no-role-passwords');
    return this;
  }

  PgDump schemaOnly() {
    _tokens.add('--schema-only');
    return this;
  }

  PgDump dataOnly() {
    _tokens.add('--data-only');
    return this;
  }

  PgDump useCopy() {
    _tokens.add('--use-copy');
    return this;
  }

  PgDump noOwner() {
    _tokens.add('--no-owner');
    return this;
  }

  PgDump noAcl() {
    _tokens.add('--no-acl');
    return this;
  }

  PgDump database(String name) {
    _tokens.add(name);
    return this;
  }
}
