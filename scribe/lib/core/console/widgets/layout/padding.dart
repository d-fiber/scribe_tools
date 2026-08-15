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
import 'edge_insets.dart';

class Padding extends RenderWidget {
  const Padding({required this.padding, this.child, super.key});

  final EdgeInsets padding;
  final Widget? child;

  @override
  List<Widget> get children {
    final Widget? content = child;
    return content == null ? const <Widget>[] : <Widget>[content];
  }

  @override
  Constraints constrainChild(int index, Constraints constraints) =>
      constraints.deflate(padding.horizontal, padding.vertical);

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    geometry?.translate(0, padding.left, padding.top);
    return paint(constraints, children);
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) {
    final Frame frame = children.isEmpty ? const Frame.empty() : children.single;
    final int inner = frame.width;
    final int width = inner + padding.horizontal;

    return Frame(<String>[
      ...List<String>.filled(padding.top, ' ' * width),
      for (final String line in frame.lines) ' ' * padding.left + padVisible(line, inner) + ' ' * padding.right,
      ...List<String>.filled(padding.bottom, ' ' * width),
    ]);
  }
}
