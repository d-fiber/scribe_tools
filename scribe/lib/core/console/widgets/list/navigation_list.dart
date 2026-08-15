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
import '../../framework/app/navigator.dart';
import '../keys/action.dart';
import '../text/text.dart';
import 'selectable_list.dart';
import 'tile.dart';

class NavigationList extends StatelessWidget {
  const NavigationList({
    required this.items,
    required this.destination,
    this.initialIndex = 0,
    this.height,
    this.showChevron = true,
    this.onChanged,
    this.onResult,
    super.key,
  }) : assert(initialIndex >= 0, 'NavigationList initialIndex must not be negative'),
       assert(height == null || height > 0, 'NavigationList height must be greater than zero');

  final List<Widget> items;
  final Widget Function(int index) destination;
  final int initialIndex;
  final int? height;
  final bool showChevron;
  final void Function(int index)? onChanged;
  final void Function(int index, Object? result)? onResult;

  static List<Action> boundActions({required int length}) => SelectableList.boundActions(length: length);

  @override
  Widget build(BuildContext context) {
    final ListStyle style = ConsoleTheme.of(context).styles.list;
    final NavigatorState navigator = Navigator.of(context);

    return SelectableList(
      items: <Widget>[for (final Widget item in items) _line(style, item)],
      initialIndex: initialIndex,
      height: height,
      onChanged: onChanged,
      onSubmit: (int index) => _open(navigator, index),
    );
  }

  Widget _line(ListStyle style, Widget item) => showChevron ? Tile(title: item, trailing: Text(style.chevron)) : item;

  Future<void> _open(NavigatorState navigator, int index) async {
    if (index < 0 || index >= items.length) return;

    final Object? result = await navigator.push<Object?>(destination(index));
    onResult?.call(index, result);
  }
}
