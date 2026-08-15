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
import 'action.dart';
import 'keyboard_listener.dart';

typedef ActionBinding = FutureOr<void> Function();

List<Action> ambientActions(BuildContext context) {
  final List<Action> collected = <Action>[];
  context.visitAncestors((Widget widget) {
    if (widget is Shortcuts) collected.addAll(widget.bindings.keys);
    return true;
  });
  return collected;
}

class Shortcuts extends StatelessWidget {
  const Shortcuts({required this.bindings, required this.child, super.key});

  final Map<Action, ActionBinding> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ConsoleRuntime? runtime = ConsoleRuntime.maybeOf(context);
    return KeyboardListener(onKey: (KeyEvent event) => _handle(runtime, event), child: child);
  }

  bool _handle(ConsoleRuntime? runtime, KeyEvent event) {
    final Action? action = Action.fromEvent(event);
    final ActionBinding? binding = action == null ? null : bindings[action];
    if (binding == null) return false;

    if (runtime == null) {
      Future<void>.sync(binding);
      return true;
    }

    runtime.spawn(binding);
    return true;
  }
}
