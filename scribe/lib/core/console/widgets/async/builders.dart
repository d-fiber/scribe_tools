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
import 'async_snapshot.dart';

typedef AsyncWidgetBuilder<T> = Widget Function(BuildContext context, AsyncSnapshot<T> snapshot);

typedef ValueWidgetBuilder<T> = Widget Function(BuildContext context, T value);

class FutureBuilder<T> extends StatefulWidget {
  const FutureBuilder({required this.future, required this.builder, this.initialData, super.key});

  final Future<T>? future;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<FutureBuilder<T>> createState() => _FutureBuilderState<T>();
}

class _FutureBuilderState<T> extends State<FutureBuilder<T>> {
  late AsyncSnapshot<T> _snapshot = _initial();
  Object? _active;

  @override
  void initState() => _subscribe();

  @override
  void didUpdateWidget(FutureBuilder<T> previous) {
    if (identical(previous.future, widget.future)) return;

    _snapshot = _initial();
    _subscribe();
  }

  @override
  void dispose() => _active = null;

  @override
  Widget build(BuildContext context) => widget.builder(context, _snapshot);

  AsyncSnapshot<T> _initial() {
    if (widget.future == null) return AsyncSnapshot<T>.nothing();
    final T? seed = widget.initialData;

    return seed == null
        ? AsyncSnapshot<T>.waiting()
        : AsyncSnapshot<T>.value(seed, connection: ConnectionState.waiting);
  }

  void _subscribe() {
    final Future<T>? future = widget.future;
    if (future == null) return;

    final Object token = Object();
    _active = token;

    future.then((T value) => _emit(token, AsyncSnapshot<T>.value(value))).catchError((Object error, StackTrace stack) {
      _emit(token, AsyncSnapshot<T>.failed(error, stack));
    });
  }

  void _emit(Object token, AsyncSnapshot<T> snapshot) {
    if (!mounted || !identical(_active, token)) return;
    setState(() => _snapshot = snapshot);
  }
}

class StreamBuilder<T> extends StatefulWidget {
  const StreamBuilder({required this.stream, required this.builder, this.initialData, super.key});

  final Stream<T>? stream;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<StreamBuilder<T>> createState() => _StreamBuilderState<T>();
}

class _StreamBuilderState<T> extends State<StreamBuilder<T>> {
  late AsyncSnapshot<T> _snapshot = _initial();
  StreamSubscription<T>? _subscription;

  @override
  void initState() => _subscribe();

  @override
  void didUpdateWidget(StreamBuilder<T> previous) {
    if (identical(previous.stream, widget.stream)) return;

    _subscription?.cancel();
    _snapshot = _initial();
    _subscribe();
  }

  @override
  void dispose() => _subscription?.cancel();

  @override
  Widget build(BuildContext context) => widget.builder(context, _snapshot);

  AsyncSnapshot<T> _initial() {
    if (widget.stream == null) return AsyncSnapshot<T>.nothing();
    final T? seed = widget.initialData;

    return seed == null
        ? AsyncSnapshot<T>.waiting()
        : AsyncSnapshot<T>.value(seed, connection: ConnectionState.waiting);
  }

  void _subscribe() {
    final Stream<T>? stream = widget.stream;
    if (stream == null) return;

    _subscription = stream.listen(
      (T value) => _emit(AsyncSnapshot<T>.value(value, connection: ConnectionState.active)),
      onError: (Object error, StackTrace stack) =>
          _emit(AsyncSnapshot<T>.failed(error, stack, connection: ConnectionState.active)),
      onDone: () => _emit(AsyncSnapshot<T>(connection: ConnectionState.done, data: _snapshot.data)),
    );
  }

  void _emit(AsyncSnapshot<T> snapshot) {
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }
}

class ListenableBuilder extends StatefulWidget {
  const ListenableBuilder({required this.listenable, required this.builder, super.key});

  final Listenable listenable;
  final WidgetBuilder builder;

  @override
  State<ListenableBuilder> createState() => _ListenableBuilderState();
}

class _ListenableBuilderState extends State<ListenableBuilder> {
  @override
  void initState() => widget.listenable.addListener(_refresh);

  @override
  void didUpdateWidget(ListenableBuilder previous) {
    if (identical(previous.listenable, widget.listenable)) return;

    previous.listenable.removeListener(_refresh);
    widget.listenable.addListener(_refresh);
  }

  @override
  void dispose() => widget.listenable.removeListener(_refresh);

  @override
  Widget build(BuildContext context) => widget.builder(context);

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }
}

class ValueListenableBuilder<T> extends StatelessWidget {
  const ValueListenableBuilder({required this.listenable, required this.builder, super.key});

  final ValueNotifier<T> listenable;
  final ValueWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: listenable, builder: (BuildContext context) => builder(context, listenable.value));
}
