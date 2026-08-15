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

class Alignment {
  const Alignment(this.x, this.y);

  static const Alignment topLeft = Alignment(-1, -1);
  static const Alignment topCenter = Alignment(0, -1);
  static const Alignment topRight = Alignment(1, -1);
  static const Alignment centerLeft = Alignment(-1, 0);
  static const Alignment center = Alignment(0, 0);
  static const Alignment centerRight = Alignment(1, 0);
  static const Alignment bottomLeft = Alignment(-1, 1);
  static const Alignment bottomCenter = Alignment(0, 1);
  static const Alignment bottomRight = Alignment(1, 1);

  final int x;
  final int y;

  int offsetFor(int axis, int free) {
    if (free <= 0) return 0;
    return switch (axis) {
      < 0 => 0,
      0 => free ~/ 2,
      _ => free,
    };
  }
}

class Align extends RenderWidget {
  const Align({this.alignment = Alignment.center, this.child, super.key});

  final Alignment alignment;
  final Widget? child;

  @override
  List<Widget> get children {
    final Widget? content = child;
    return content == null ? const <Widget>[] : <Widget>[content];
  }

  @override
  Constraints constrainChild(int index, Constraints constraints) => constraints.loose;

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    final Frame frame = children.isEmpty ? const Frame.empty() : children.single;
    final int width = constraints.constrainWidth(frame.width);
    final int height = constraints.constrainHeight(frame.height);

    geometry?.translate(
      0,
      alignment.offsetFor(alignment.x, width - frame.width),
      alignment.offsetFor(alignment.y, height - frame.height),
    );

    return paint(constraints, children);
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) {
    final Frame frame = children.isEmpty ? const Frame.empty() : children.single;
    final int width = constraints.constrainWidth(frame.width);
    final int height = constraints.constrainHeight(frame.height);

    final int left = alignment.offsetFor(alignment.x, width - frame.width);
    final int top = alignment.offsetFor(alignment.y, height - frame.height);
    final int bottom = height - frame.height - top < 0 ? 0 : height - frame.height - top;

    return Frame(<String>[
      ...List<String>.filled(top, ' ' * width),
      for (final String line in frame.lines) padVisible(' ' * left + line, width),
      ...List<String>.filled(bottom, ' ' * width),
    ]);
  }
}

class Center extends Align {
  const Center({super.child, super.key}) : super(alignment: Alignment.center);
}
