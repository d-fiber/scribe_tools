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

import 'package:string_validator/string_validator.dart';

import '../../../core/console/console.dart';

const List<String> protectedAccounts = <String>['noreply', 'account'];
const List<String> smtpPath = <String>['api', 'config', 'smtp'];
const List<String> _accountFields = <String>['host', 'port', 'user', 'pass'];

List<MenuValue> smtpFields(String account, {SuffixBuilder suffix = requiredValue}) => <MenuValue>[
  for (final String field in _accountFields)
    MenuValue(field, <String>[...smtpPath, account, field], suffix: suffix, validate: _validator(field)),
];

MenuEntry apiEntry({SuffixBuilder suffix = requiredValue}) =>
    MenuGroup('api', (MenuDocument _) => <MenuEntry>[smtpEntry(suffix: suffix)]);

MenuEntry smtpEntry({SuffixBuilder suffix = requiredValue}) => MenuGroup(
  'smtp',
  (MenuDocument document) => <MenuEntry>[
    for (final String account in _accountNames(document))
      MenuGroup(account, (MenuDocument _) => smtpFields(account, suffix: suffix), key: account),
  ],
  onAdd: _add,
  onRemove: _remove,
);

void seedSmtp(MenuDocument document) {
  for (final String account in protectedAccounts) {
    if (document.node(<String>[...smtpPath, account]) != null) continue;
    _createAccount(document, account);
  }
}

String? smtpError(MenuDocument document) {
  for (final String account in protectedAccounts) {
    for (final MenuValue field in smtpFields(account)) {
      if (!document.filled(field.path)) {
        return 'Fill in ${field.label} for the $account smtp account before saving.';
      }
    }
    if (int.tryParse(document.read(<String>[...smtpPath, account, 'port'])) == null) {
      return 'port for the $account smtp account must be a number.';
    }
    if (!isEmail(document.read(<String>[...smtpPath, account, 'user']))) {
      return 'user for the $account smtp account must be a valid email.';
    }
  }
  return null;
}

void _createAccount(MenuDocument document, String account) {
  for (final MenuValue field in smtpFields(account)) {
    document.write(field.path, '');
  }
}

List<String> _accountNames(MenuDocument document) {
  final dynamic node = document.node(smtpPath);
  final List<String> names = node is Map ? node.keys.map((dynamic k) => k.toString()).toList() : <String>[];
  names.sort();
  return names;
}

Future<String?> _add(MenuActions actions) async {
  final String? account = await actions.promptName('Account name');
  if (account == null) return null;
  if (account.trim().isEmpty) return 'Account name is missing';
  if (actions.document.node(<String>[...smtpPath, account]) != null) {
    return 'An account named "$account" already exists';
  }

  _createAccount(actions.document, account);
  await actions.notify();
  return null;
}

Future<String?> _remove(MenuActions actions, Object? key) async {
  final String account = key! as String;
  if (protectedAccounts.contains(account)) return "$account is required and can't be deleted";
  if (!await actions.confirm('Delete "$account"?')) return null;

  actions.document.remove(<String>[...smtpPath, account]);
  await actions.notify();
  return null;
}

FieldValidator _validator(String label) => (String value) {
  if (value.trim().isEmpty) return '$label is missing';
  if (value.length > 1000) return '$label is too long';

  if (label == 'port') {
    final int? port = int.tryParse(value);
    if (port == null) return 'port must be a number';
    if (port > 100000) return 'port must not be greater than 100000';
  }
  if (label == 'user' && !isEmail(value)) return 'user must be a valid email';

  return null;
};
