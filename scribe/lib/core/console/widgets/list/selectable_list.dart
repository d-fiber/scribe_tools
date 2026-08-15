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

import 'dart:async';

import '../../framework/framework.dart';
import '../keys/action.dart';
import '../keys/focus.dart';
import '../keys/shortcuts.dart';
import '../pointer/pointer_listener.dart';
import 'list_selection.dart';
import 'selection_cursor.dart';

class SelectableList extends StatefulWidget {
  const SelectableList({
    required this.items,
    this.initialIndex = 0,
    this.height,
    this.wrap = true,
    this.focusable = true,
    this.showPrefix = true,
    this.onChanged,
    this.onSubmit,
    super.key,
  }) : assert(initialIndex >= 0, 'SelectableList initialIndex must not be negative'),
       assert(height == null || height > 0, 'SelectableList height must be greater than zero');

  final List<Widget> items;
  final int initialIndex;
  final int? height;
  final bool wrap;
  final bool focusable;
  final bool showPrefix;
  final void Function(int index)? onChanged;
  final FutureOr<void> Function(int index)? onSubmit;

  static List<Action> boundActions({required int length, bool submit = true}) => <Action>[
    if (length > 1) Action.up,
    if (length > 1) Action.down,
    if (submit) Action.enter,
  ];

  @override
  State<SelectableList> createState() => _SelectableListState();
}

class _SelectableListState extends State<SelectableList> {
  late SelectionCursor _cursor = SelectionCursor(index: widget.initialIndex);

  int get _length => widget.items.length;

  int _height(BuildContext context) => widget.height ?? ConsoleTheme.of(context).styles.list.height;

  @override
  Widget build(BuildContext context) {
    final int height = _height(context);
    final SelectionCursor cursor = _cursor.clamped(length: _length, height: height);

    final Widget list = ListSelection(
      items: widget.items,
      cursor: cursor,
      height: height,
      showPrefix: widget.showPrefix,
    );

    final Widget listening = Shortcuts(
      bindings: <Action, ActionBinding>{
        if (_length > 1) Action.up: () => _move(-1, height),
        if (_length > 1) Action.down: () => _move(1, height),
        if (_length > 1) Action.home: () => _apply(_cursor.first(length: _length, height: height)),
        if (_length > 1) Action.end: () => _apply(_cursor.last(length: _length, height: height)),
        if (_length > 1) Action.pageUp: () => _apply(_cursor.page(-1, length: _length, height: height)),
        if (_length > 1) Action.pageDown: () => _apply(_cursor.page(1, length: _length, height: height)),
        if (widget.onSubmit != null) Action.enter: () => widget.onSubmit!(cursor.index),
      },
      child: PointerListener(onPointer: (MouseEvent event) => _wheel(event, height), child: list),
    );

    return widget.focusable ? Focus(child: listening) : listening;
  }

  void _move(int step, int height) => _apply(_cursor.moveBy(step, length: _length, height: height, wrap: widget.wrap));

  bool _wheel(MouseEvent event, int height) {
    final int step = switch (event.button) {
      MouseButton.wheelUp => -1,
      MouseButton.wheelDown => 1,
      _ => 0,
    };
    if (step == 0) return false;

    _move(step, height);
    return true;
  }

  void _apply(SelectionCursor next) {
    if (next.index == _cursor.index && next.offset == _cursor.offset) return;

    setState(() => _cursor = next);
    widget.onChanged?.call(next.index);
  }
}
