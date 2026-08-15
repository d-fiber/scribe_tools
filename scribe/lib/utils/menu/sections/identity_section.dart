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

import '../../../core/machine.dart';
import '../../../core/console/console.dart';

const List<String> namePath = <String>['name'];
const List<String> urlPath = <String>['url'];
const List<String> emailPath = <String>['email'];
const List<String> machinePath = <String>['machine'];

List<MenuEntry> identityEntries({SuffixBuilder suffix = requiredValue}) => <MenuEntry>[
  MenuValue('name', namePath, suffix: suffix, validate: _name),
  MenuValue('url', urlPath, suffix: suffix, validate: _url),
  MenuValue('email', emailPath, suffix: suffix, validate: _email),
  MenuValue(
    'machine',
    machinePath,
    suffix: suffix,
    choices: MenuChoices(prompt: 'Machine you deploy on', ids: machineIds, labels: machineLabels),
  ),
];

void seedIdentity(MenuDocument document) {
  if (!document.filled(machinePath)) document.write(machinePath, autoMachineId);
}

String? identityError(MenuDocument document) {
  if (!document.filled(namePath)) return 'Fill in name before saving.';
  if (document.read(namePath).length < 4) return 'name must be at least 4 characters.';
  if (!document.filled(urlPath)) return 'Fill in url before saving.';
  if (!isURL(document.read(urlPath))) return 'url is not valid.';
  if (!document.filled(emailPath)) return 'Fill in email before saving.';
  if (!isEmail(document.read(emailPath))) return 'email is not valid.';
  if (!machineIds.contains(document.read(machinePath))) return 'Pick the machine you deploy on before saving.';
  return null;
}

String? _name(String value) {
  if (value.trim().isEmpty) return 'name is missing';
  if (value.length < 4) return 'name must be at least 4 characters';
  if (value.length > 1000) return 'name is too long';
  return null;
}

String? _url(String value) {
  if (value.trim().isEmpty) return 'url is missing';
  if (value.length > 1000) return 'url is too long';
  if (!isURL(value)) return 'url is not valid';
  return null;
}

String? _email(String value) {
  if (value.trim().isEmpty) return 'email is missing';
  if (value.length > 1000) return 'email is too long';
  if (!isEmail(value)) return 'email is not valid';
  return null;
}
