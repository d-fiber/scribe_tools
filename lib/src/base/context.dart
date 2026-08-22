// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'dart:async';

/// A generator that asked, directly or through another one, for the type it is building.
///
/// [cycle] lists the types in the order they were requested, the one that
/// closed the loop last.
class ContextDependencyCycleException implements Exception {
  /// Reports the loop [cycle] walked through.
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
    final AppContext child = AppContext._(
      this,
      name,
      Map<Type, Generator>.unmodifiable(overrides ?? <Type, Generator>{}),
    );

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
