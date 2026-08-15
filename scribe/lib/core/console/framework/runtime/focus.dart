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

part of '../framework.dart';

class FocusNode {
  FocusManager? _manager;
  Element? _element;

  bool get hasFocus => _manager?.focusedNode == this;

  void requestFocus() => _manager?.requestFocus(this);

  void unfocus() => _manager?.release(this);
}

class FocusManager {
  FocusManager(this.onChanged);

  final void Function() onChanged;

  final List<FocusNode> _order = <FocusNode>[];
  FocusNode? _focused;

  static FocusManager? maybeOf(BuildContext context) => ConsoleRuntime.maybeOf(context)?.focus;

  FocusNode? get focusedNode {
    final FocusNode? focused = _focused;
    return focused != null && _order.contains(focused) ? focused : null;
  }

  Element? get focusedElement => focusedNode?._element;

  List<FocusNode> get order => List<FocusNode>.unmodifiable(_order);

  void beginFrame() => _order.clear();

  void register(FocusNode node, Element element) {
    node._manager = this;
    node._element = element;
    if (!_order.contains(node)) _order.add(node);
  }

  void requestFocus(FocusNode node) {
    if (_focused == node) return;
    _focused = node;
    onChanged();
  }

  void release(FocusNode node) {
    if (_focused != node) return;
    _focused = null;
    onChanged();
  }

  bool next() => _move(1);

  bool previous() => _move(-1);

  bool _move(int step) {
    if (_order.isEmpty) return false;

    final FocusNode? focused = _focused;
    final int index = focused == null ? -1 : _order.indexOf(focused);
    requestFocus(_order[(index + step + _order.length) % _order.length]);

    return true;
  }
}
