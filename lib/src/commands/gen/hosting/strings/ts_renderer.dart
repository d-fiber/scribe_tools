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

import 'dart:convert';

import 'package:scribe_tools/src/commands/gen/hosting/strings/entries.dart';
import 'package:scribe_tools/src/commands/gen/hosting/strings/template.dart';

/// The TypeScript module holding [entries], [bin] naming the command that rewrites it.
///
/// A string carrying no placeholder becomes a value, one carrying some becomes
/// a function taking them, so a caller cannot forget to substitute one.
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
