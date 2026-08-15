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

abstract class Registration {
  Registration(this.owner);

  final Element owner;

  Rect region = Rect.zero;

  void resize(int width, int height) => region = region.resized(width, height);

  void translate(int dx, int dy) => region = region.shifted(dx, dy);
}

class KeyRegistration extends Registration {
  KeyRegistration(super.owner, this.handler);

  final KeyHandler handler;
}

class PointerRegistration extends Registration {
  PointerRegistration(super.owner, this.handler);

  final PointerHandler handler;
}

class Painter {
  final List<Registration> _registrations = <Registration>[];

  int get length => _registrations.length;

  KeyRegistration listen(KeyHandler handler, {required Element owner}) {
    final KeyRegistration registration = KeyRegistration(owner, handler);
    _registrations.add(registration);
    return registration;
  }

  PointerRegistration listenPointer(PointerHandler handler, {required Element owner}) {
    final PointerRegistration registration = PointerRegistration(owner, handler);
    _registrations.add(registration);
    return registration;
  }

  void translate(int start, int end, int dx, int dy) {
    for (int index = start; index < end && index < _registrations.length; index++) {
      _registrations[index].translate(dx, dy);
    }
  }

  bool dispatchKey(KeyEvent event, {Element? focused}) {
    for (final KeyHandler handler in _keyHandlers(focused)) {
      if (handler(event)) return true;
    }
    return false;
  }

  bool dispatchPointer(MouseEvent event) {
    for (final PointerRegistration pointer in _pointersAt(event.column, event.row)) {
      if (pointer.handler(event)) return true;
    }
    return false;
  }

  List<PointerRegistration> _pointersAt(int x, int y) {
    final List<PointerRegistration> hit = <PointerRegistration>[];
    for (final Registration registration in _registrations.reversed) {
      if (registration is! PointerRegistration || !registration.region.contains(x, y)) continue;
      hit.add(registration);
    }
    hit.sort((PointerRegistration first, PointerRegistration second) => second.owner.depth - first.owner.depth);

    return hit;
  }

  List<KeyHandler> _keyHandlers(Element? focused) {
    final List<KeyRegistration> keys = <KeyRegistration>[
      for (final Registration registration in _registrations)
        if (registration is KeyRegistration) registration,
    ];

    if (focused == null) {
      return <KeyHandler>[for (final KeyRegistration key in keys.reversed) key.handler];
    }

    final Set<Element> ancestors = _pathTo(focused);
    final List<KeyRegistration> scoped =
        keys.where((KeyRegistration key) => _inScope(key.owner, focused, ancestors)).toList()
          ..sort((KeyRegistration first, KeyRegistration second) => second.owner.depth - first.owner.depth);

    return <KeyHandler>[for (final KeyRegistration key in scoped) key.handler];
  }

  bool _inScope(Element owner, Element focused, Set<Element> ancestors) {
    if (ancestors.contains(owner)) return true;

    Element? current = owner;
    while (current != null) {
      if (current == focused) return true;
      current = current._parent;
    }
    return false;
  }

  Set<Element> _pathTo(Element focused) {
    final Set<Element> path = <Element>{focused};
    Element? ancestor = focused._parent;
    while (ancestor != null) {
      path.add(ancestor);
      ancestor = ancestor._parent;
    }
    return path;
  }
}
