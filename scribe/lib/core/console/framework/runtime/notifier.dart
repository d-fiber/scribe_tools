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

typedef VoidCallback = void Function();

abstract interface class Listenable {
  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = <VoidCallback>[];

  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final VoidCallback listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  void dispose() => _listeners.clear();
}

class ValueNotifier<T> extends ChangeNotifier {
  ValueNotifier(this._value);

  T _value;

  T get value => _value;

  set value(T next) {
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }
}

class Ticker {
  Ticker(this.onTick, {this.interval = const Duration(milliseconds: 80)});

  final void Function(int tick) onTick;
  final Duration interval;

  Timer? _timer;
  int _tick = 0;

  bool get isActive => _timer != null;

  int get tick => _tick;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (Timer timer) {
      _tick++;
      onTick(_tick);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
