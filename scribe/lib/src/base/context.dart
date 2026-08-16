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

/// A generator that asked, directly or through another one, for the type it is building.
///
/// [cycle] lists the types in the order they were requested, the one that
/// closed the loop last.
class ContextDependencyCycleException implements Exception {
  const ContextDependencyCycleException(this.cycle);

  /// The chain of types that led back to itself.
  final List<Type> cycle;

  @override
  String toString() => 'Dependency cycle detected: ${cycle.join(' -> ')}';
}

/// A function that builds the value a context serves for one type.
typedef Generator = Object? Function();

/// The dependency container the zone carries.
///
/// A generator runs at most once per context, and the value it returns lives as
/// long as that context does. A lookup that finds nothing here walks up to the
/// parent, so a child overrides only the types it names and inherits the rest.
class AppContext {
  AppContext._(this._parent, this._name, [this._overrides = const <Type, Generator>{}]);

  static const Object _key = Object();

  final AppContext? _parent;
  final String? _name;
  final Map<Type, Generator> _overrides;
  final Map<Type, Object?> _values = <Type, Object?>{};

  final List<Type> _reentrantChecks = <Type>[];

  /// The name this context was opened under, or `app` when it was given none.
  String get name => _name ?? 'app';

  /// The context the current zone carries, or the root one outside any [run].
  static AppContext get current => Zone.current[_key] as AppContext? ?? _root;

  static final AppContext _root = AppContext._(null, 'root');

  /// The value registered for [T] here or in an enclosing context, or null.
  T? get<T extends Object>() {
    final Object? value = _generateIfNecessary(T);
    if (value != null) return value as T;
    return _parent?.get<T>();
  }

  /// Runs [body] in a child context that adds [overrides], and returns its result.
  ///
  /// The child is carried by a zone, so everything [body] calls and everything
  /// it awaits sees the same overrides without being handed them.
  ///
  /// Throws a [ContextDependencyCycleException] when a generator ends up asking
  /// for the type it is building.
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
