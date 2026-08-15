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
import 'shortcuts.dart';

enum Action {
  up,
  down,
  left,
  right,
  upDown,
  leftRight,
  home,
  end,
  pageUp,
  pageDown,
  tab,
  backTab,
  enter,
  space,
  backspace,
  delete,
  esc,
  quit,
  save,
  create,
  open,
  add,
  remove,
  edit,
  search,
  refresh,
  undo,
  redo,
  toggle,
  help;

  static Action? fromEvent(KeyEvent event) {
    for (final Action action in values) {
      if (action.isCombined) continue;
      if (action.matches(event)) return action;
    }
    return null;
  }

  bool get isCombined => this == Action.upDown || this == Action.leftRight;

  bool matches(KeyEvent event) => switch (this) {
    Action.upDown || Action.leftRight => false,
    Action.space => !event.isControl && event.char == ' ',
    Action.tab => event.control == ControlCharacter.tab && !event.shift,
    Action.backTab => event.control == ControlCharacter.tab && event.shift,
    Action.backspace => event.control == ControlCharacter.backspace || event.control == ControlCharacter.ctrlH,
    _ => event.isControl && event.control == _control,
  };

  bool covers(Action other) =>
      this == other ||
      (this == Action.upDown && (other == Action.up || other == Action.down)) ||
      (this == Action.leftRight && (other == Action.left || other == Action.right));

  ControlCharacter? get _control => switch (this) {
    Action.up => ControlCharacter.arrowUp,
    Action.down => ControlCharacter.arrowDown,
    Action.left => ControlCharacter.arrowLeft,
    Action.right => ControlCharacter.arrowRight,
    Action.home => ControlCharacter.home,
    Action.end => ControlCharacter.end,
    Action.pageUp => ControlCharacter.pageUp,
    Action.pageDown => ControlCharacter.pageDown,
    Action.enter => ControlCharacter.enter,
    Action.delete => ControlCharacter.delete,
    Action.esc => ControlCharacter.escape,
    Action.quit => ControlCharacter.ctrlQ,
    Action.save => ControlCharacter.ctrlS,
    Action.create => ControlCharacter.ctrlN,
    Action.open => ControlCharacter.ctrlO,
    Action.add => ControlCharacter.ctrlA,
    Action.remove => ControlCharacter.ctrlD,
    Action.edit => ControlCharacter.ctrlE,
    Action.search => ControlCharacter.ctrlF,
    Action.refresh => ControlCharacter.ctrlR,
    Action.undo => ControlCharacter.ctrlZ,
    Action.redo => ControlCharacter.ctrlY,
    Action.toggle => ControlCharacter.ctrlT,
    Action.help => ControlCharacter.F1,
    Action.tab || Action.backTab || Action.space || Action.backspace => null,
    Action.upDown || Action.leftRight => null,
  };

  String get icon => switch (this) {
    Action.up => '↑',
    Action.down => '↓',
    Action.left => '←',
    Action.right => '→',
    Action.upDown => '↑↓',
    Action.leftRight => '←→',
    Action.home => 'Home',
    Action.end => 'End',
    Action.pageUp => 'PgUp',
    Action.pageDown => 'PgDn',
    Action.tab => '⇥',
    Action.backTab => '⇤',
    Action.enter => '⏎',
    Action.space => 'Space',
    Action.backspace => '⌫',
    Action.delete => 'Del',
    Action.esc => 'Esc',
    Action.quit => 'Ctrl+Q',
    Action.save => 'Ctrl+S',
    Action.create => 'Ctrl+N',
    Action.open => 'Ctrl+O',
    Action.add => 'Ctrl+A',
    Action.remove => 'Ctrl+D',
    Action.edit => 'Ctrl+E',
    Action.search => 'Ctrl+F',
    Action.refresh => 'Ctrl+R',
    Action.undo => 'Ctrl+Z',
    Action.redo => 'Ctrl+Y',
    Action.toggle => 'Ctrl+T',
    Action.help => 'F1',
  };

  String get label => switch (this) {
    Action.up => 'up',
    Action.down => 'down',
    Action.left => 'left',
    Action.right => 'right',
    Action.upDown => 'navigate',
    Action.leftRight => 'navigate',
    Action.home => 'first',
    Action.end => 'last',
    Action.pageUp => 'page up',
    Action.pageDown => 'page down',
    Action.tab => 'next field',
    Action.backTab => 'previous field',
    Action.enter => 'enter',
    Action.space => 'select',
    Action.backspace => 'erase',
    Action.delete => 'delete',
    Action.esc => 'escape',
    Action.quit => 'quit',
    Action.save => 'save',
    Action.create => 'new',
    Action.open => 'open',
    Action.add => 'add',
    Action.remove => 'delete',
    Action.edit => 'edit',
    Action.search => 'search',
    Action.refresh => 'refresh',
    Action.undo => 'undo',
    Action.redo => 'redo',
    Action.toggle => 'toggle',
    Action.help => 'help',
  };
}

class ActionBar extends StatelessWidget {
  const ActionBar({this.actions, super.key});

  final List<Action>? actions;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    return Row(
      children: <Widget>[
        for (final Action action in merged(actions ?? ambientActions(context)))
          Row(
            children: <Widget>[
              Text(action.icon, color: theme.colors.text.primary),
              const Text(' '),
              Text(action.label, color: theme.colors.text.secondary),
            ],
          ),
      ],
      separator: const Text(' • '),
    );
  }

  static List<Action> merged(List<Action> actions) {
    final List<Action> unique = actions.toSet().toList()
      ..sort((Action first, Action second) => first.index - second.index);

    return _pair(_pair(unique, Action.up, Action.down, Action.upDown), Action.left, Action.right, Action.leftRight);
  }

  static List<Action> _pair(List<Action> actions, Action first, Action second, Action combined) {
    if (!actions.contains(first) || !actions.contains(second)) return actions;
    return <Action>[
      for (final Action action in actions)
        if (action == first) combined else if (action != second) action,
    ];
  }
}
