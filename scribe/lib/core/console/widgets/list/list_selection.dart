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
import '../layout/row.dart';
import '../text/text.dart';
import 'list_view.dart';
import 'selection_cursor.dart';

class ListSelection extends StatelessWidget {
  const ListSelection({required this.items, required this.cursor, this.height, this.showPrefix = true, super.key})
    : assert(height == null || height > 0, 'ListSelection height must be greater than zero');

  final List<Widget> items;
  final SelectionCursor cursor;
  final int? height;
  final bool showPrefix;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final int rows = height ?? theme.styles.list.height;
    final int start = SelectionCursor.scrolled(
      offset: cursor.offset,
      selected: cursor.index,
      count: items.length,
      height: rows,
    );

    return ListView(
      items: <Widget>[for (int index = 0; index < items.length; index++) _line(theme, index)],
      height: rows,
      offset: start,
    );
  }

  Widget _line(ConsoleTheme theme, int index) {
    final bool active = index == cursor.index;
    final Widget item = active ? _Active(items[index], color: theme.colors.action.primary) : items[index];
    if (!showPrefix) return item;

    return Row(
      children: <Widget>[
        Text(
          active ? theme.styles.list.activePrefix : theme.styles.list.inactivePrefix,
          color: active ? theme.colors.action.primary : Colors.transparent,
        ),
        const Text(' '),
        item,
      ],
    );
  }
}

class _Active extends RenderWidget {
  const _Active(this.child, {required this.color});

  final Widget child;
  final Color color;

  @override
  List<Widget> get children => <Widget>[child];

  @override
  Frame paint(Constraints constraints, List<Frame> children) =>
      Frame(<String>[for (final String line in children.single.lines) color.paint(line)]);
}
