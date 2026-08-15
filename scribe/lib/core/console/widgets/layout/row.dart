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
import 'flex.dart';

class Row extends RenderWidget {
  const Row({
    required List<Widget> children,
    this.separator,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    super.key,
  }) : _items = children;

  final List<Widget> _items;
  final Widget? separator;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  List<Widget> get children {
    final Widget? gap = separator;
    if (gap == null) return _items;

    return <Widget>[
      for (int index = 0; index < _items.length; index++) ...<Widget>[if (index > 0) gap, _items[index]],
    ];
  }

  @override
  Frame layout(Constraints constraints, ChildPainter children) {
    final List<Widget> widgets = this.children;
    final List<int> flexes = <int>[for (final Widget child in widgets) flexOf(child)];
    final Constraints childConstraints = Constraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight);
    final List<Frame> frames = List<Frame>.filled(flexes.length, const Frame.empty());

    int used = 0;
    for (int index = 0; index < flexes.length; index++) {
      if (flexes[index] > 0) continue;
      frames[index] = children.paint(index, childConstraints);
      used += frames[index].width;
    }

    final int? maxWidth = constraints.maxWidth;
    final int free = maxWidth == null ? 0 : maxWidth - used;
    final List<int> shares = distribute(flexes, free < 0 ? 0 : free);
    for (int index = 0; index < flexes.length; index++) {
      if (flexes[index] == 0) continue;
      final int share = shares[index];
      final bool tight = fitOf(widgets[index]) == FlexFit.tight;
      final Constraints shareConstraints = tight
          ? childConstraints.tightenWidth(share)
          : Constraints(maxWidth: share, maxHeight: constraints.maxHeight);
      final Frame painted = children.paint(index, shareConstraints);
      frames[index] = tight ? painted.padded(share) : painted;
    }

    return compose(constraints, frames, children);
  }

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    final int content = children.fold(0, (int total, Frame child) => total + child.width);
    final int height = constraints.constrainHeight(
      children.fold(0, (int tallest, Frame child) => child.height > tallest ? child.height : tallest),
    );

    final int width = mainAxisSize == MainAxisSize.max && constraints.hasBoundedWidth
        ? constraints.maxWidth!
        : constraints.constrainWidth(content);
    final List<int> gaps = spacingFor(mainAxisAlignment, width - content, children.length);

    final List<Frame> blocks = <Frame>[];
    int column = 0;
    for (int index = 0; index < children.length; index++) {
      if (gaps[index] > 0) {
        blocks.add(_gap(gaps[index], height));
        column += gaps[index];
      }

      final Frame child = children[index];
      geometry?.translate(index, column, _indent(child.height, height));
      blocks.add(_align(child, height));
      column += child.width;
    }
    if (gaps[children.length] > 0) blocks.add(_gap(gaps[children.length], height));

    return Frame.beside(blocks);
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) => compose(constraints, children, null);

  Frame _gap(int width, int height) => Frame(List<String>.filled(height, ' ' * width));

  int _indent(int childHeight, int height) {
    final int missing = height - childHeight;
    if (missing <= 0) return 0;

    return switch (crossAxisAlignment) {
      CrossAxisAlignment.start || CrossAxisAlignment.stretch => 0,
      CrossAxisAlignment.end => missing,
      CrossAxisAlignment.center => missing ~/ 2,
    };
  }

  Frame _align(Frame frame, int height) {
    final int missing = height - frame.height;
    if (missing <= 0) return frame;

    final List<String> blank = List<String>.filled(missing, '');
    return switch (crossAxisAlignment) {
      CrossAxisAlignment.start || CrossAxisAlignment.stretch => Frame(<String>[...frame.lines, ...blank]),
      CrossAxisAlignment.end => Frame(<String>[...blank, ...frame.lines]),
      CrossAxisAlignment.center => Frame(<String>[
        ...blank.sublist(0, missing ~/ 2),
        ...frame.lines,
        ...blank.sublist(missing ~/ 2),
      ]),
    };
  }
}
