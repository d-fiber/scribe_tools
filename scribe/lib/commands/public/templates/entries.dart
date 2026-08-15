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

import '../../../core/logger.dart';

/// Parsed `strings.csv` (one per template folder under
/// `lib/public/mails/templates/`). The set of languages is
/// whatever the header declares after `id;` no hardcoded `en`/`fr`: add a
/// column, add a language.
class MailL10nSource {
  MailL10nSource({required this.locales, required this.defaultLocale, required this.entries});

  /// Language codes in header order (`Comment;id;en;fr;...` → `[en, fr, ...]`).
  final List<String> locales;

  /// First language after `id;` required on every row, other languages fall
  /// back to it when missing.
  final String defaultLocale;

  /// `key -> { locale -> value }`, always fully populated (fallback already applied).
  final Map<String, Map<String, String>> entries;
}

String _at(List<String> parts, int index) => parts.length > index ? parts[index].trim() : '';

MailL10nSource parseMailEntries(String csv, Log log, String sourcePath) {
  final List<String> lines = csv.split('\n').map((String l) => l.trim()).where((String l) => l.isNotEmpty).toList();

  if (lines.isEmpty) {
    log.error('$sourcePath is empty.');
  }

  final List<String> header = lines.first.split(';');
  if (header.length < 3 || _at(header, 0) != 'Comment' || _at(header, 1) != 'id') {
    log.error(
      '$sourcePath: first line must be "Comment;id;<lang1>;<lang2>;..." '
      '(got "${lines.first}").',
    );
  }

  final List<String> locales = header.sublist(2).map((String l) => l.trim()).toList();
  if (locales.isEmpty || locales.any((String l) => l.isEmpty)) {
    log.error(
      '$sourcePath: header must declare at least one language after "id;" '
      '(got "${lines.first}").',
    );
  }
  final String defaultLocale = locales.first;

  final Map<String, Map<String, String>> entries = <String, Map<String, String>>{};
  int fallbackCount = 0;

  for (final String line in lines.skip(1)) {
    if (line.startsWith('Comment')) continue; // tolerate an accidental repeated header
    final List<String> parts = line.split(';');
    final String id = _at(parts, 1);
    if (id.isEmpty) continue;

    // Default language is required on every row a row missing it entirely
    // has no translation at all, which is an error, not something to fall
    // back from.
    final String defaultValue = _at(parts, 2);
    if (defaultValue.isEmpty) {
      log.error(
        '$sourcePath: row "$id" has no translation for the default '
        'language ("$defaultLocale"). Every row needs at least the default language.',
      );
    }

    final Map<String, String> row = <String, String>{};
    for (int i = 0; i < locales.length; i++) {
      final String value = _at(parts, 2 + i);
      if (value.isEmpty) fallbackCount++;
      row[locales[i]] = value.isEmpty ? defaultValue : value;
    }
    entries[id] = row;
  }

  if (fallbackCount > 0) {
    log.warn('$fallbackCount translation(s) missing in $sourcePath → fell back to "$defaultLocale".');
  }

  return MailL10nSource(locales: locales, defaultLocale: defaultLocale, entries: entries);
}
