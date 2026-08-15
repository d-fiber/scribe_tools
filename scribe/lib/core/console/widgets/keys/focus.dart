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

class Focus extends Widget {
  const Focus({required this.child, this.focusNode, this.autofocus = false, super.key});

  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;

  static bool isFocused(BuildContext context) {
    final Focus? enclosing = context.findAncestorWidgetOfExactType<Focus>();
    return enclosing?.focusNode?.hasFocus ?? false;
  }

  @override
  Element createElement() => _FocusElement(this);
}

class _FocusElement extends ComponentElement {
  _FocusElement(Focus super.widget);

  final FocusNode _own = FocusNode();

  bool _requested = false;

  Focus get focus => widget as Focus;

  FocusNode get node => focus.focusNode ?? _own;

  @override
  Widget build() => focus.child;

  @override
  Frame paint(Painter painter, Constraints constraints) {
    final FocusManager? manager = FocusManager.maybeOf(this);
    if (manager != null) {
      manager.register(node, this);
      if (focus.autofocus && !_requested && manager.focusedNode == null) {
        _requested = true;
        manager.requestFocus(node);
      }
    }

    return super.paint(painter, constraints);
  }

  @override
  void unmount() {
    node.unfocus();
    super.unmount();
  }
}
