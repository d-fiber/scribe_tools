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

import 'sql.dart';

class Eq implements SqlExpression {
  Eq(this.left, this.right);

  final SqlExpression left;
  final SqlExpression right;

  @override
  String render() => '${left.render()} = ${right.render()}';
}

class IsNull implements SqlExpression {
  IsNull(this.expression);

  final SqlExpression expression;

  @override
  String render() => '${expression.render()} IS NULL';
}

class And implements SqlExpression {
  And(this.conditions);

  final List<SqlExpression> conditions;

  @override
  String render() =>
      conditions.map((SqlExpression c) => c.render()).join(' AND ');
}

class Or implements SqlExpression {
  Or(this.conditions);

  final List<SqlExpression> conditions;

  @override
  String render() =>
      conditions.map((SqlExpression c) => c.render()).join(' OR ');
}

class NotExists implements SqlExpression {
  NotExists(this.subquery);

  final Sql subquery;

  @override
  String render() => 'NOT EXISTS (${subquery.render()})';
}
