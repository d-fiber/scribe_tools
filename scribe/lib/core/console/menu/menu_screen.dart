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

import '../framework/framework.dart';
import '../framework/app/navigator.dart';
import '../widgets/input/text_input.dart';
import '../widgets/keys/action.dart';
import '../widgets/keys/shortcuts.dart';
import '../widgets/layout/column.dart';
import '../widgets/list/selectable_list.dart';
import '../widgets/list/tile.dart';
import '../widgets/text/text.dart';
import 'menu_document.dart';
import 'menu_entry.dart';
import 'menu_scope.dart';
import 'select_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({required this.title, required this.entries, this.onAdd, this.onRemove, super.key});

  MenuScreen.group(MenuGroup group)
    : title = group.label,
      entries = group.children,
      onAdd = group.onAdd,
      onRemove = group.onRemove,
      super(key: group.key);

  final String title;
  final EntryBuilder entries;
  final Future<String?> Function(MenuActions actions)? onAdd;
  final Future<String?> Function(MenuActions actions, Object? key)? onRemove;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _index = 0;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final MenuController controller = MenuScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ListStyle style = theme.styles.list;
    final List<MenuEntry> entries = widget.entries(controller.document);
    final int index = entries.isEmpty ? 0 : _index.clamp(0, entries.length - 1);
    final int width = _labelWidth(entries);

    final Map<Action, ActionBinding> bindings = <Action, ActionBinding>{
      if (navigator.canPop) Action.esc: navigator.pop,
      Action.quit: () => _quit(controller, navigator),
      if (controller.editable && widget.onAdd != null) Action.add: () => _report(widget.onAdd!(_actions(controller))),
      if (controller.editable && widget.onRemove != null && entries.isNotEmpty)
        Action.remove: () => _report(widget.onRemove!(_actions(controller), _keyOf(entries[index]))),
    };

    return Shortcuts(
      bindings: bindings,
      child: Column(
        children: <Widget>[
          Text(widget.title, color: theme.colors.text.primary, style: TextStyle.bold),
          const Text(''),
          SelectableList(
            items: <Widget>[for (final MenuEntry entry in entries) _item(controller, style, entry, width)],
            initialIndex: index,
            onChanged: _select,
            onSubmit: (int selected) => _enter(controller, navigator, entries, selected),
          ),
          const Text(''),
          ActionBar(
            actions: <Action>[
              ...SelectableList.boundActions(length: entries.length),
              ...bindings.keys,
            ],
          ),
          if (_status case final String status) Text(status, color: theme.colors.feedback.error),
        ],
      ),
    );
  }

  MenuActions _actions(MenuController controller) => _ScreenActions(controller, context);

  int _labelWidth(List<MenuEntry> entries) =>
      entries.fold(0, (int widest, MenuEntry entry) => entry.label.length > widest ? entry.label.length : widest) + 2;

  Object? _keyOf(MenuEntry entry) => entry is MenuGroup ? entry.key : null;

  Widget _item(MenuController controller, ListStyle style, MenuEntry entry, int width) => switch (entry) {
    MenuGroup group => Tile(title: Text(group.label), trailing: Text(style.chevron)),
    MenuValue value => Tile(
      title: Text(value.label),
      titleWidth: width,
      trailing: value.suffix(controller.document.read(value.path)),
    ),
  };

  void _select(int index) {
    setState(() {
      _index = index;
      _status = null;
    });
  }

  Future<void> _enter(MenuController controller, NavigatorState navigator, List<MenuEntry> entries, int index) async {
    if (entries.isEmpty) return;
    setState(() => _status = null);

    final MenuEntry entry = entries[index];
    if (entry is MenuGroup) {
      await navigator.push<void>(MenuScreen.group(entry));
      return;
    }
    if (!controller.editable) return;

    final MenuValue value = entry as MenuValue;
    final String? entered = await _read(controller, navigator, value);
    if (entered == null) return;

    controller.document.write(value.path, entered);
    await controller.notify();
    setState(() {});
  }

  Future<String?> _read(MenuController controller, NavigatorState navigator, MenuValue value) async {
    final MenuChoices? choices = value.choices;
    if (choices == null) {
      return navigator.push<String>(
        TextInput(
          label: value.label,
          initialValue: controller.document.read(value.path),
          validate: value.validate ?? (String entered) => entered.length > 1000 ? '${value.label} is too long' : null,
        ),
      );
    }

    final int current = choices.ids.indexOf(controller.document.read(value.path));
    final int? picked = await navigator.push<int>(
      SelectScreen(prompt: choices.prompt, options: choices.labels, initialIndex: current < 0 ? 0 : current),
    );
    return picked == null ? null : choices.ids[picked];
  }

  void _quit(MenuController controller, NavigatorState navigator) {
    final String? error = controller.completionError?.call();
    if (error == null) {
      navigator.close();
      return;
    }
    setState(() => _status = error);
  }

  Future<void> _report(Future<String?> outcome) async {
    final String? status = await outcome;
    setState(() => _status = status);
  }
}

class _ScreenActions implements MenuActions {
  _ScreenActions(this.controller, this.context);

  final MenuController controller;
  final BuildContext context;

  @override
  MenuDocument get document => controller.document;

  @override
  Future<void> notify() => controller.notify();

  @override
  Future<String?> promptName(String label) => Navigator.of(context).push<String>(TextInput(label: label));

  @override
  Future<bool> confirm(String prompt) async =>
      await Navigator.of(context).push<int>(SelectScreen(prompt: prompt, options: const <String>['no', 'yes'])) == 1;
}
