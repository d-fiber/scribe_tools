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
import 'alignment.dart';
import 'decoration.dart';
import 'edge_insets.dart';
import 'padding.dart';
import 'sized_box.dart';

class Container extends StatelessWidget {
  const Container({
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
    this.background = Colors.transparent,
    this.border = Border.none,
    super.key,
  });

  final Widget? child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final int? width;
  final int? height;
  final Constraints? constraints;
  final Alignment? alignment;
  final Color background;
  final Border border;

  @override
  Widget build(BuildContext context) {
    Widget? current = child;

    final Alignment? position = alignment;
    if (position != null) current = Align(alignment: position, child: current);

    final EdgeInsets? inner = padding;
    if (inner != null) current = Padding(padding: inner, child: current);

    if (border.style != BorderStyle.none || !background.isTransparent) {
      current = DecoratedBox(border: border, background: background, child: current);
    }

    final Constraints? limits = constraints;
    if (limits != null) current = ConstrainedBox(constraints: limits, child: current);

    if (width != null || height != null) current = SizedBox(width: width, height: height, child: current);

    final EdgeInsets? outer = margin;
    if (outer != null) current = Padding(padding: outer, child: current);

    return current ?? const SizedBox();
  }
}
