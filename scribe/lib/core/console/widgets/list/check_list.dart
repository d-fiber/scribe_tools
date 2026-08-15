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
import '../keys/shortcuts.dart';
import '../layout/row.dart';
import '../text/text.dart';
import 'selectable_list.dart';

enum SelectionMode { single, multiple }

class CheckList extends StatefulWidget {
  CheckList.single({
    required this.items,
    int? selected,
    this.initialIndex = 0,
    this.height,
    this.onChanged,
    this.onSubmit,
    super.key,
  }) : assert(selected == null || selected >= 0, 'CheckList selected must not be negative'),
       assert(initialIndex >= 0, 'CheckList initialIndex must not be negative'),
       mode = SelectionMode.single,
       initialSelection = selected == null ? const <int>{} : <int>{selected};

  const CheckList.multiple({
    required this.items,
    Set<int> selected = const <int>{},
    this.initialIndex = 0,
    this.height,
    this.onChanged,
    this.onSubmit,
    super.key,
  }) : assert(initialIndex >= 0, 'CheckList initialIndex must not be negative'),
       mode = SelectionMode.multiple,
       initialSelection = selected;

  final List<Widget> items;
  final SelectionMode mode;
  final Set<int> initialSelection;
  final int initialIndex;
  final int? height;
  final void Function(Set<int> selection)? onChanged;
  final FutureOr<void> Function(Set<int> selection)? onSubmit;

  static List<Action> boundActions({required int length, bool submit = true}) => <Action>[
    ...SelectableList.boundActions(length: length, submit: submit),
    Action.space,
  ];

  @override
  State<CheckList> createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  late Set<int> _selection = <int>{...widget.initialSelection};
  late int _index = widget.initialIndex;

  bool get _isSingle => widget.mode == SelectionMode.single;

  @override
  Widget build(BuildContext context) {
    final ListStyle style = ConsoleTheme.of(context).styles.list;

    return Shortcuts(
      bindings: <Action, ActionBinding>{Action.space: _toggle},
      child: SelectableList(
        items: <Widget>[for (int index = 0; index < widget.items.length; index++) _line(style, index)],
        initialIndex: widget.initialIndex,
        height: widget.height,
        onChanged: (int index) => _index = index,
        onSubmit: widget.onSubmit == null ? null : (int index) => widget.onSubmit!(_selection),
      ),
    );
  }

  Widget _line(ListStyle style, int index) =>
      Row(children: <Widget>[Text(_mark(style, _selection.contains(index))), const Text(' '), widget.items[index]]);

  String _mark(ListStyle style, bool selected) {
    if (_isSingle) return selected ? style.selected : style.unselected;
    return selected ? style.checked : style.unchecked;
  }

  void _toggle() {
    if (widget.items.isEmpty) return;

    final int index = _index.clamp(0, widget.items.length - 1);
    setState(() => _selection = _isSingle ? <int>{index} : _switched(index));
    widget.onChanged?.call(_selection);
  }

  Set<int> _switched(int index) =>
      _selection.contains(index) ? (<int>{..._selection}..remove(index)) : (<int>{..._selection}..add(index));
}
