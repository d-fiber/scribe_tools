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

class ContextDependencyCycleException implements Exception {
  const ContextDependencyCycleException(this.cycle);

  final List<Type> cycle;

  @override
  String toString() => 'Dependency cycle detected: ${cycle.join(' -> ')}';
}

typedef Generator = Object? Function();

class AppContext {
  AppContext._(this._parent, this._name, [this._overrides = const <Type, Generator>{}]);

  static const Object _key = Object();

  final AppContext? _parent;
  final String? _name;
  final Map<Type, Generator> _overrides;
  final Map<Type, Object?> _values = <Type, Object?>{};

  final List<Type> _reentrantChecks = <Type>[];

  String get name => _name ?? 'app';

  static AppContext get current => Zone.current[_key] as AppContext? ?? _root;

  static final AppContext _root = AppContext._(null, 'root');

  T? get<T extends Object>() {
    final Object? value = _generateIfNecessary(T);
    if (value != null) return value as T;
    return _parent?.get<T>();
  }

  Future<V> run<V>({required FutureOr<V> Function() body, String? name, Map<Type, Generator>? overrides}) async {
    final AppContext child = AppContext._(this, name, Map<Type, Generator>.unmodifiable(overrides ?? <Type, Generator>{}));

    return runZoned<Future<V>>(() async => await body(), zoneValues: <Object, Object>{_key: child});
  }

  Object? _generateIfNecessary(Type type) {
    if (!_overrides.containsKey(type)) return null;
    if (_values.containsKey(type)) return _values[type];

    if (_reentrantChecks.contains(type)) {
      throw ContextDependencyCycleException(List<Type>.unmodifiable(<Type>[..._reentrantChecks, type]));
    }

    _reentrantChecks.add(type);
    try {
      return _values[type] = _overrides[type]!();
    } finally {
      _reentrantChecks.removeLast();
    }
  }

  @override
  String toString() => 'AppContext($name)';
}
