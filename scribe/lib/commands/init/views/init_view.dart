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

import '../../../core/console/console.dart';
import 'machine_view.dart';
import 'name_view.dart';
import 'summary_view.dart';

class InitView extends StatefulWidget {
  const InitView({super.key});

  @override
  State<InitView> createState() => _InitViewState();
}

class _InitViewState extends State<InitView> {
  static const List<String> _machines = <String>['auto', 'b3-8', 'b3-16'];
  static const List<String> _entries = <String>[NameView.label, MachineView.label, SummaryView.label];
  static const int _labelWidth = 16;

  String _name = '';
  String _machine = '';

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final Map<Action, ActionBinding> bindings = <Action, ActionBinding>{Action.quit: Navigator.of(context).close};

    return Shortcuts(
      bindings: bindings,
      child: Column(
        children: <Widget>[
          Text(Scope.of(context).invocation, color: theme.colors.text.primary, style: TextStyle.bold),
          const Text(''),
          NavigationList(
            items: <Widget>[for (int index = 0; index < _entries.length; index++) _entry(theme, index)],
            destination: _destination,
            showChevron: false,
            onResult: _record,
          ),
          const Text(''),
          ActionBar(
            actions: <Action>[
              ...NavigationList.boundActions(length: _entries.length),
              ...bindings.keys,
            ],
          ),
        ],
      ),
    );
  }

  Widget _entry(ConsoleTheme theme, int index) {
    final String chosen = _chosen(index);

    return Tile(
      title: Text(_entries[index]),
      titleWidth: _labelWidth,
      trailing: chosen.isEmpty ? Text(theme.styles.list.chevron) : Text(chosen, color: theme.colors.feedback.success),
    );
  }

  String _chosen(int index) => switch (index) {
    0 => _name,
    1 => _machine,
    _ => '',
  };

  Widget _destination(int index) => switch (index) {
    0 => NameView(value: _name),
    1 => MachineView(options: _machines, value: _machine),
    _ => SummaryView(name: _name, machine: _machine),
  };

  void _record(int index, Object? result) {
    if (index == 0 && result is String) setState(() => _name = result);
    if (index == 1 && result is int) setState(() => _machine = _machines[result]);
  }
}
