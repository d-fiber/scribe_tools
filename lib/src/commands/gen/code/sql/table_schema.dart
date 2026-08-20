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

import 'sql_type_mapper.dart';

class Col {
  Col(this.name, this.ts, this.enumName);

  final String name;
  final String ts;
  final String? enumName;
}

class TableSchema {
  TableSchema(this.name, this.cols);

  final String name;
  final List<Col> cols;
}

final RegExp createTableRe = RegExp(
  r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\(([\s\S]*?)\);',
  caseSensitive: false,
);

final RegExp alterTableAddColumnRe = RegExp(
  r'alter\s+table\s+(?:if\s+exists\s+)?public\.(\w+)\s+([\s\S]*?);',
  caseSensitive: false,
);

final RegExp _constraintRe = RegExp(r'^(primary\s+key|foreign\s+key|unique|check|constraint)\b', caseSensitive: false);

final RegExp _addColumnRe = RegExp(
  r'^add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)\s+((?:public\.)?\w+(?:\([\d\s,]+\))?(?:\[\])?)(.*)?$',
  caseSensitive: false,
);

final RegExp _columnRe = RegExp(r'^(\w+)\s+((?:public\.)?\w+(?:\([\d\s,]+\))?(?:\[\])?)(.*)?$', caseSensitive: false);

Col _colFromMatch(RegExpMatch m) {
  final String colName = m.group(1)!;
  final String sqlType = m.group(2)!;
  final String rest = (m.group(3) ?? '').toLowerCase();
  final bool notNull = rest.contains('not null') || rest.contains('primary key');

  final MappedType mapped = mapSqlType(sqlType);
  return Col(colName, notNull ? mapped.ts : '${mapped.ts} | null', mapped.enumName);
}

int _parenDelta(String line) => '('.allMatches(line).length - ')'.allMatches(line).length;

List<Col> parseColumns(String body) {
  final List<Col> cols = <Col>[];

  int skipDepth = 0;

  for (final String raw in body.split('\n')) {
    String line = raw.trim();
    if (line.endsWith(',')) line = line.substring(0, line.length - 1);
    if (line.isEmpty) continue;

    if (skipDepth > 0) {
      skipDepth += _parenDelta(line);
      continue;
    }

    if (_constraintRe.hasMatch(line)) {
      final int delta = _parenDelta(line);
      if (delta > 0) skipDepth = delta;
      continue;
    }

    final RegExpMatch? m = _columnRe.firstMatch(line);
    if (m == null) continue;

    cols.add(_colFromMatch(m));
  }
  return cols;
}

List<Col> parseAlterAddColumns(String body) {
  final List<Col> cols = <Col>[];
  for (final String raw in body.split('\n')) {
    String line = raw.trim();
    if (line.endsWith(',') || line.endsWith(';')) line = line.substring(0, line.length - 1);
    if (line.isEmpty) continue;

    final RegExpMatch? m = _addColumnRe.firstMatch(line);
    if (m == null) continue;

    cols.add(_colFromMatch(m));
  }
  return cols;
}
