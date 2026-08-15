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

class Column extends RenderWidget {
  const Column({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    super.key,
  });

  @override
  final List<Widget> children;

  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Frame layout(Constraints constraints, ChildPainter children) {
    final List<int> flexes = <int>[for (final Widget child in this.children) flexOf(child)];
    final Constraints childConstraints = Constraints(maxWidth: constraints.maxWidth);
    final List<Frame> frames = List<Frame>.filled(flexes.length, const Frame.empty());

    int used = 0;
    for (int index = 0; index < flexes.length; index++) {
      if (flexes[index] > 0) continue;
      frames[index] = children.paint(index, childConstraints);
      used += frames[index].height;
    }

    final int? maxHeight = constraints.maxHeight;
    final int free = maxHeight == null ? 0 : maxHeight - used;
    final List<int> shares = distribute(flexes, free < 0 ? 0 : free);
    for (int index = 0; index < flexes.length; index++) {
      if (flexes[index] == 0) continue;
      final int share = shares[index];
      final bool tight = fitOf(this.children[index]) == FlexFit.tight;
      final Constraints shareConstraints = tight
          ? childConstraints.tightenHeight(share)
          : Constraints(maxWidth: constraints.maxWidth, maxHeight: share);
      final Frame painted = children.paint(index, shareConstraints);
      frames[index] = tight ? _fitHeight(painted, share) : painted;
    }

    return compose(constraints, frames, children);
  }

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    final int content = children.fold(0, (int total, Frame child) => total + child.height);
    final int width = constraints.constrainWidth(
      children.fold(0, (int widest, Frame child) => child.width > widest ? child.width : widest),
    );

    final int height = mainAxisSize == MainAxisSize.max && constraints.hasBoundedHeight
        ? constraints.maxHeight!
        : constraints.constrainHeight(content);
    final List<int> gaps = spacingFor(mainAxisAlignment, height - content, children.length);

    final List<String> lines = <String>[];
    int row = 0;
    for (int index = 0; index < children.length; index++) {
      lines.addAll(List<String>.filled(gaps[index], ''));
      row += gaps[index];

      final Frame child = children[index];
      geometry?.translate(index, _indent(child.width, width), row);
      lines.addAll(child.lines.map((String line) => _align(line, width)));
      row += child.height;
    }
    lines.addAll(List<String>.filled(gaps[children.length], ''));

    return Frame(lines);
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) => compose(constraints, children, null);

  int _indent(int childWidth, int width) {
    final int missing = width - childWidth;
    if (missing <= 0) return 0;

    return switch (crossAxisAlignment) {
      CrossAxisAlignment.start || CrossAxisAlignment.stretch => 0,
      CrossAxisAlignment.end => missing,
      CrossAxisAlignment.center => missing ~/ 2,
    };
  }

  String _align(String line, int width) {
    final int missing = width - visibleWidth(line);
    if (missing <= 0) return line;

    return switch (crossAxisAlignment) {
      CrossAxisAlignment.start => line,
      CrossAxisAlignment.stretch => line + ' ' * missing,
      CrossAxisAlignment.end => ' ' * missing + line,
      CrossAxisAlignment.center => ' ' * (missing ~/ 2) + line,
    };
  }

  Frame _fitHeight(Frame frame, int height) {
    if (frame.height == height) return frame;
    if (frame.height > height) return Frame(frame.lines.sublist(0, height));
    return Frame(<String>[...frame.lines, ...List<String>.filled(height - frame.height, '')]);
  }
}
