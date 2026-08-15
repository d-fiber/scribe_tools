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

abstract class SqlExpression {
  String render();
}

class Raw implements SqlExpression {
  Raw(this.text);

  final String text;

  @override
  String render() => text;
}

class Sql implements SqlExpression {
  final List<String> _fragments = <String>[];
  bool _inSetClause = false;

  Sql _append(String fragment) {
    _fragments.add(fragment);
    return this;
  }

  Sql select(List<SqlExpression> columns) {
    _inSetClause = false;
    return _append(
      'SELECT ${columns.map((SqlExpression c) => c.render()).join(', ')}',
    );
  }

  Sql insertInto(String table, List<String> columns) {
    _inSetClause = false;
    return _append('INSERT INTO $table (${columns.join(', ')})');
  }

  Sql updateTable(String table) {
    _inSetClause = false;
    return _append('UPDATE $table');
  }

  Sql set(String column, SqlExpression value) {
    final String assignment = '$column = ${value.render()}';
    if (!_inSetClause) {
      _inSetClause = true;
      return _append('SET $assignment');
    }
    _fragments[_fragments.length - 1] = '${_fragments.last}, $assignment';
    return this;
  }

  Sql from(String table, {String? alias}) {
    _inSetClause = false;
    return _append(alias == null ? 'FROM $table' : 'FROM $table $alias');
  }

  Sql where(SqlExpression condition) {
    _inSetClause = false;
    return _append('WHERE ${condition.render()}');
  }

  Sql limit(int n) {
    _inSetClause = false;
    return _append('LIMIT $n');
  }

  @override
  String render() => _fragments.join(' ');
}
