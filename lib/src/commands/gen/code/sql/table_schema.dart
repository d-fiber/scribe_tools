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
