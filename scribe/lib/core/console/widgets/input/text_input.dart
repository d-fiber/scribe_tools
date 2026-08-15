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
import '../keys/focus.dart';
import '../keys/keyboard_listener.dart';
import '../keys/shortcuts.dart';
import '../layout/column.dart';
import '../layout/row.dart';
import '../text/label.dart';
import '../text/text.dart';

class TextInput extends StatefulWidget {
  const TextInput({required this.label, this.initialValue = '', this.isRequired = false, this.validate, super.key});

  final String label;
  final String initialValue;
  final bool isRequired;
  final String? Function(String value)? validate;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late String _value = widget.initialValue;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    return Focus(
      autofocus: true,
      child: Shortcuts(
        bindings: <Action, ActionBinding>{Action.enter: _submit, Action.esc: _cancel},
        child: KeyboardListener(
          onKey: _edit,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Label(widget.label, isRequired: widget.isRequired),
                  Text(theme.styles.input.separator),
                  Text(_value),
                  Text(theme.styles.input.caret, color: theme.colors.text.placeholder),
                ],
              ),
              if (_error case final String error) Text(error, color: theme.colors.feedback.error) else const Text(''),
              const Text(''),
              const ActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  bool _edit(KeyEvent event) {
    if (Action.backspace.matches(event)) {
      if (_value.isNotEmpty) setState(() => _value = _value.substring(0, _value.length - 1));
      return true;
    }
    if (event.isControl || event.alt) return false;
    setState(() => _value += event.char);
    return true;
  }

  void _submit() {
    final String? error = widget.validate?.call(_value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_value);
  }

  void _cancel() => Navigator.of(context).pop();
}
