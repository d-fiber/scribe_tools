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

import 'dart:convert';

import 'entries.dart';
import 'template.dart';

String renderStringsModule(String bin, Map<String, Entry> entries) {
  final String dataBody = entries.entries
      .map(
        (MapEntry<String, Entry> e) =>
            '  ${e.key}: '
            '{ en: ${jsonEncode(e.value.en)}, fr: ${jsonEncode(e.value.fr)} },',
      )
      .join('\n');

  final String accessorBody = entries.entries
      .map((MapEntry<String, Entry> e) {
        final List<String> params = extractParams(e.value.en);
        if (params.isEmpty) {
          return '    ${e.key}: _data.${e.key}[locale],';
        }
        final String paramType = params.map((String p) => '$p: string').join('; ');
        final String replaceChain = params.map((String p) => '.replace("{$p}", p.$p)').join();
        return '    ${e.key}: (p: { $paramType }) => '
            '_data.${e.key}[locale]$replaceChain,';
      })
      .join('\n');

  return '''
// AUTO-GENERATED do not edit manually
// File: strings.csv run `$bin gen hosting` to update

export const locales = ["en", "fr"] as const;
export type Locale = typeof locales[number];

const _data = {
$dataBody
} as const;

export type StringKey = keyof typeof _data;

export function t(key: StringKey, locale: Locale): string {
  return _data[key][locale];
}

export function strings(locale: Locale) {
  return {
$accessorBody
  };
}
''';
}
