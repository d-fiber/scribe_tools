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
import 'placeholders.dart';

class MailL10nModule {
  MailL10nModule(this.localeFiles, this.strings);

  /// One rendered `<locale>.ts` per language, in header order.
  final Map<String, String> localeFiles;
  final String strings;
}

String _header(String sourcePath) =>
    '''
// AUTO-GENERATED do not edit manually
// Source: $sourcePath — run `./koko public --generate templates` to update
''';

// Long-form name -> ISO code, for aliasing public.localization's enum values
// ('english', 'french', ...) to the short codes used in strings.csv. Only
// entries whose code is actually declared in the CSV header make it into the
// generated `_aliases` map extend this list when a new language needs the
// long-form alias (the DB enum value itself is a separate manual migration,
// this only maps the string once it exists).
const Map<String, String> _knownLocaleNames = <String, String>{
  'english': 'en',
  'french': 'fr',
  'spanish': 'es',
  'italian': 'it',
  'german': 'de',
  'portuguese': 'pt',
  'dutch': 'nl',
  'polish': 'pl',
  'russian': 'ru',
  'arabic': 'ar',
  'japanese': 'ja',
  'korean': 'ko',
  'chinese': 'zh',
  'turkish': 'tr',
  'swedish': 'sv',
  'danish': 'da',
  'norwegian': 'no',
  'finnish': 'fi',
  'greek': 'el',
  'czech': 'cs',
  'romanian': 'ro',
  'hungarian': 'hu',
  'ukrainian': 'uk',
  'hebrew': 'he',
  'hindi': 'hi',
  'indonesian': 'id',
  'thai': 'th',
  'vietnamese': 'vi',
};

MailL10nModule renderMailL10nModule(MailL10nSource source, String sourcePath) {
  final Map<String, String> localeFiles = <String, String>{
    for (final String locale in source.locales)
      locale: _renderLocaleFile(
        locale,
        source.entries.map((String k, Map<String, String> v) => MapEntry<String, String>(k, v[locale]!)),
        sourcePath,
      ),
  };

  return MailL10nModule(localeFiles, _renderStringsFile(source, sourcePath));
}

String _renderLocaleFile(String locale, Map<String, String> values, String sourcePath) {
  final String body = values.entries
      .map((MapEntry<String, String> e) => '  ${e.key}: ${jsonEncode(e.value)},')
      .join('\n');

  return '''
${_header(sourcePath)}
export const $locale = {
$body
} as const;
''';
}

// app_name/app_name_slug are the same across every string in a single
// `.lang()` call so `.lang()` resolves them itself instead of making each
// individual string's accessor take them as a param only placeholders that
// vary per-string become per-string function params. The value itself comes
// from `.lang()`'s own `appName` parameter (passed explicitly by the caller,
// e.g. from `Env.APP_NAME` at the call site) never read from `Env` in here.
const Set<String> _globalPlaceholderNames = <String>{'app_name', 'app_name_slug'};

String _renderStringsFile(MailL10nSource source, String sourcePath) {
  final String imports = source.locales
      .map((String locale) => 'import { $locale } from "./arb/$locale.ts";')
      .join('\n');

  final String localesArray = source.locales.map((String l) => '"$l"').join(', ');
  final String dataObject = source.locales.join(', ');

  final Map<String, String> aliases = <String, String>{
    for (final MapEntry<String, String> e in _knownLocaleNames.entries)
      if (source.locales.contains(e.value)) e.key: e.value,
  };
  final String aliasesBody = aliases.entries
      .map((MapEntry<String, String> e) => '  ${e.key}: "${e.value}",')
      .join('\n');

  // Placeholders are detected on the default language's copy only if a
  // translation uses a placeholder the default doesn't have, it won't be
  // substituted for that locale (same limitation `gen hosting` documents for
  // its own EN-only detection).
  final String accessorBody = source.entries.entries
      .map((MapEntry<String, Map<String, String>> e) {
        final String defaultText = e.value[source.defaultLocale]!;
        final List<MailPlaceholder> all = extractMailPlaceholders(defaultText);
        final List<MailPlaceholder> globals = all
            .where((MailPlaceholder p) => _globalPlaceholderNames.contains(p.name))
            .toList();
        final List<MailPlaceholder> params = all
            .where((MailPlaceholder p) => !_globalPlaceholderNames.contains(p.name))
            .toList();

        final String globalChain = globals
            .map((MailPlaceholder p) => '.replace(${jsonEncode(p.token)}, String(_global.${p.name}))')
            .join();

        if (params.isEmpty) {
          return '      ${e.key}: data.${e.key}$globalChain,';
        }
        final String paramType = params.map((MailPlaceholder p) => '${p.name}: ${p.tsType}').join('; ');
        final String paramChain = params
            .map((MailPlaceholder p) => '.replace(${jsonEncode(p.token)}, String(p.${p.name}))')
            .join();
        return '      ${e.key}: (p: { $paramType }) => data.${e.key}$globalChain$paramChain,';
      })
      .join('\n');

  return '''
${_header(sourcePath)}
$imports

export const locales = [$localesArray] as const;
export type Locale = (typeof locales)[number];

const _data = { $dataObject } as const;

const _aliases: Record<string, Locale> = {
$aliasesBody
};

function _resolveLocale(locale: string | null): Locale {
  if (!locale) return "${source.defaultLocale}";
  const lower = locale.toLowerCase();
  if ((locales as readonly string[]).includes(lower)) return lower as Locale;
  return _aliases[lower] ?? "${source.defaultLocale}";
}

function _slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+\$/g, "");
}

export const S = {
  lang(locale: string | null, appName: string) {
    const data = _data[_resolveLocale(locale)];
    const _global = {
      app_name: appName,
      app_name_slug: _slugify(appName),
    };
    return {
$accessorBody
    };
  },
};
''';
}
