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

import '../../framework/framework.dart';
import '../layout/row.dart';
import '../text/text.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    this.total = 1,
    this.width,
    this.label,
    this.color,
    this.showPercent = true,
    super.key,
  }) : assert(total > 0, 'ProgressBar total must be greater than zero');

  final num value;
  final num total;
  final int? width;
  final String? label;
  final Color? color;
  final bool showPercent;

  double get fraction => (value / total).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final ProgressStyle style = theme.styles.progress;
    final int columns = width ?? style.width;
    final int filled = (columns * fraction).round();
    final String text = label ?? '';

    return Row(
      children: <Widget>[
        if (text.isNotEmpty) ...<Widget>[Text(text, color: theme.colors.text.primary), const Text(' ')],
        Text(style.filled * filled, color: color ?? theme.colors.action.primary),
        Text(style.empty * (columns - filled), color: theme.colors.surface.fill),
        if (showPercent) ...<Widget>[
          const Text(' '),
          Text('${(fraction * 100).round()}%'.padLeft(4), color: theme.colors.text.secondary),
        ],
      ],
    );
  }
}
