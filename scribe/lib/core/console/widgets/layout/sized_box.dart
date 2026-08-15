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

class ConstrainedBox extends RenderWidget {
  const ConstrainedBox({required this.constraints, this.child, super.key});

  final Constraints constraints;
  final Widget? child;

  @override
  List<Widget> get children {
    final Widget? content = child;
    return content == null ? const <Widget>[] : <Widget>[content];
  }

  @override
  Constraints constrainChild(int index, Constraints constraints) => this.constraints;

  @override
  Frame paint(Constraints constraints, List<Frame> children) =>
      children.isEmpty ? const Frame.empty() : children.single;
}

class SizedBox extends RenderWidget {
  const SizedBox({this.width, this.height, this.child, super.key})
    : assert(width == null || width >= 0, 'SizedBox width must not be negative'),
      assert(height == null || height >= 0, 'SizedBox height must not be negative');

  const SizedBox.expand({this.child, super.key}) : width = null, height = null;

  final int? width;
  final int? height;
  final Widget? child;

  @override
  List<Widget> get children {
    final Widget? content = child;
    return content == null ? const <Widget>[] : <Widget>[content];
  }

  @override
  Constraints constrainChild(int index, Constraints constraints) => Constraints(
    minWidth: width ?? constraints.minWidth,
    maxWidth: width ?? constraints.maxWidth,
    minHeight: height ?? constraints.minHeight,
    maxHeight: height ?? constraints.maxHeight,
  );

  bool overflows(Constraints constraints) {
    final int? requestedWidth = width;
    final int? maxWidth = constraints.maxWidth;
    if (requestedWidth != null && maxWidth != null && requestedWidth > maxWidth) return true;

    final int? requestedHeight = height;
    final int? maxHeight = constraints.maxHeight;
    return requestedHeight != null && maxHeight != null && requestedHeight > maxHeight;
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) {
    if (overflows(constraints)) return const Frame.empty();

    final Frame frame = children.isEmpty ? const Frame.empty() : children.single;
    final int rows = height ?? constraints.constrainHeight(frame.height);
    final int columns = width ?? constraints.constrainWidth(frame.width);

    final List<String> lines = <String>[
      for (int row = 0; row < rows; row++) padVisible(row < frame.height ? frame.lines[row] : '', columns),
    ];
    return Frame(lines);
  }
}
