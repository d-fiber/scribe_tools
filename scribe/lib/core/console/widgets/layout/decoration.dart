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

enum BorderStyle { none, single, rounded, thick, doubled }

class Border {
  const Border({this.style = BorderStyle.single, this.color});

  static const Border none = Border(style: BorderStyle.none);

  final BorderStyle style;
  final Color? color;

  int get thickness => style == BorderStyle.none ? 0 : 1;

  Border withColor(Color value) => color == null ? Border(style: style, color: value) : this;

  String get topLeft => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single => '┌',
    BorderStyle.rounded => '╭',
    BorderStyle.thick => '┏',
    BorderStyle.doubled => '╔',
  };

  String get topRight => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single => '┐',
    BorderStyle.rounded => '╮',
    BorderStyle.thick => '┓',
    BorderStyle.doubled => '╗',
  };

  String get bottomLeft => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single => '└',
    BorderStyle.rounded => '╰',
    BorderStyle.thick => '┗',
    BorderStyle.doubled => '╚',
  };

  String get bottomRight => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single => '┘',
    BorderStyle.rounded => '╯',
    BorderStyle.thick => '┛',
    BorderStyle.doubled => '╝',
  };

  String get horizontal => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single || BorderStyle.rounded => '─',
    BorderStyle.thick => '━',
    BorderStyle.doubled => '═',
  };

  String get vertical => switch (style) {
    BorderStyle.none => '',
    BorderStyle.single || BorderStyle.rounded => '│',
    BorderStyle.thick => '┃',
    BorderStyle.doubled => '║',
  };
}

class DecoratedBox extends StatelessWidget {
  const DecoratedBox({this.border = Border.none, this.background = Colors.transparent, this.child, super.key});

  final Border border;
  final Color background;
  final Widget? child;

  @override
  Widget build(BuildContext context) => _Decoration(
    border: border.withColor(ConsoleTheme.of(context).colors.outline.border),
    background: background,
    child: child,
  );
}

class _Decoration extends RenderWidget {
  const _Decoration({required this.border, required this.background, this.child});

  final Border border;
  final Color background;
  final Widget? child;

  @override
  List<Widget> get children {
    final Widget? content = child;
    return content == null ? const <Widget>[] : <Widget>[content];
  }

  @override
  Constraints constrainChild(int index, Constraints constraints) =>
      constraints.deflate(2 * border.thickness, 2 * border.thickness);

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    geometry?.translate(0, border.thickness, border.thickness);
    return paint(constraints, children);
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) {
    final Frame frame = children.isEmpty ? const Frame.empty() : children.single;
    final int inner = frame.width;
    final List<String> lines = <String>[for (final String line in frame.lines) padVisible(line, inner)];

    if (border.thickness == 0) return Frame(<String>[for (final String line in lines) _fill(line)]);

    final Color color = border.color ?? ConsoleColors.detected.outline.border;
    final String side = color.paint(border.vertical);

    return Frame(<String>[
      _fill(color.paint(border.topLeft + border.horizontal * inner + border.topRight)),
      for (final String line in lines) _fill(side + line + side),
      _fill(color.paint(border.bottomLeft + border.horizontal * inner + border.bottomRight)),
    ]);
  }

  String _fill(String line) => background.isTransparent ? line : background.fill(line);
}
