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
import '../keys/action.dart';
import '../keys/focus.dart';
import '../keys/keyboard_listener.dart';
import '../pointer/pointer_listener.dart';

class SingleChildScrollView extends StatefulWidget {
  const SingleChildScrollView({
    required this.child,
    this.scrollable = true,
    this.focusable = true,
    this.initialOffset = 0,
    this.wheelStep = 3,
    super.key,
  });

  final Widget child;
  final bool scrollable;
  final bool focusable;
  final int initialOffset;
  final int wheelStep;

  @override
  State<SingleChildScrollView> createState() => _SingleChildScrollViewState();
}

class _SingleChildScrollViewState extends State<SingleChildScrollView> {
  late int _offset = widget.initialOffset;
  int _extent = 0;
  int _viewport = 0;

  int get _maxOffset => _extent - _viewport < 0 ? 0 : _extent - _viewport;

  @override
  Widget build(BuildContext context) {
    final Widget viewport = _Viewport(offset: _offset, onLayout: _measure, child: widget.child);
    if (!widget.scrollable) return viewport;

    final Widget listening = PointerListener(
      onPointer: _wheel,
      child: KeyboardListener(onKey: _scroll, child: viewport),
    );

    return widget.focusable ? Focus(child: listening) : listening;
  }

  void _measure(int extent, int viewport) {
    _extent = extent;
    _viewport = viewport;
  }

  bool _wheel(MouseEvent event) {
    final int step = switch (event.button) {
      MouseButton.wheelUp => -widget.wheelStep,
      MouseButton.wheelDown => widget.wheelStep,
      _ => 0,
    };
    return _moveBy(step);
  }

  bool _scroll(KeyEvent event) {
    final int step = switch (Action.fromEvent(event)) {
      Action.up => -1,
      Action.down => 1,
      Action.pageUp => -_viewport,
      Action.pageDown => _viewport,
      Action.home => -_extent,
      Action.end => _extent,
      _ => 0,
    };
    return _moveBy(step);
  }

  bool _moveBy(int step) {
    if (step == 0) return false;

    final int next = (_offset + step).clamp(0, _maxOffset);
    if (next == _offset) return false;

    setState(() => _offset = next);
    return true;
  }
}

class _Viewport extends RenderWidget {
  const _Viewport({required this.child, required this.offset, required this.onLayout});

  final Widget child;
  final int offset;
  final void Function(int extent, int viewport) onLayout;

  @override
  List<Widget> get children => <Widget>[child];

  @override
  Constraints constrainChild(int index, Constraints constraints) => constraints.unboundedHeight;

  @override
  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) {
    final Frame frame = children.single;
    final int? maxHeight = constraints.maxHeight;
    final int height = maxHeight == null || frame.height < maxHeight ? frame.height : maxHeight;
    onLayout(frame.height, height);

    final int start = offset.clamp(0, frame.height - height < 0 ? 0 : frame.height - height);
    geometry?.translate(0, 0, -start);

    return Frame(frame.lines.sublist(start, start + height));
  }

  @override
  Frame paint(Constraints constraints, List<Frame> children) => compose(constraints, children, null);
}
