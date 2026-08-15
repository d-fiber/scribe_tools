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

import '../framework.dart';

typedef RouteFactory = Widget Function(String name);

Widget resolveRoute(String name, Map<String, WidgetBuilder> routes, RouteFactory? onUnknownRoute) {
  final WidgetBuilder? builder = routes[name];
  if (builder != null) return Builder(builder);

  final RouteFactory? unknown = onUnknownRoute;
  if (unknown != null) return unknown(name);

  final String known = routes.keys.isEmpty ? 'none' : routes.keys.join(', ');
  throw StateError(
    'No route named "$name". Declared routes: $known. '
    'Give ConsoleApp.routed a routes entry for "$name", an onUnknownRoute, or use ConsoleApp(home: ...).',
  );
}

class Navigator extends StatefulWidget {
  const Navigator({required this.home, this.routes = const <String, WidgetBuilder>{}, this.onUnknownRoute, super.key});

  final Widget home;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory? onUnknownRoute;

  static NavigatorState of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('Navigator.of() found no Navigator above this widget. Wrap it in a ConsoleApp.'));

  static NavigatorState? maybeOf(BuildContext context) => context.findAncestorStateOfType<NavigatorState>();

  @override
  NavigatorState createState() => NavigatorState();
}

class NavigatorState extends State<Navigator> {
  final List<_Route> _routes = <_Route>[];

  bool get canPop => _routes.length > 1;

  int get depth => _routes.length;

  @override
  void initState() => _routes.add(_Route(widget.home));

  Future<R?> pushNamed<R>(String name) => push<R>(resolveRoute(name, widget.routes, widget.onUnknownRoute));

  Future<R?> push<R>(Widget screen) {
    final _Route route = _Route(screen);
    setState(() => _routes.add(route));
    return route.completer.future.then((Object? result) => result as R?);
  }

  void pop([Object? result]) {
    if (_routes.isEmpty) return;
    final _Route route = _routes.removeLast();
    route.completer.complete(result);
    if (_routes.isEmpty) {
      ConsoleRuntime.of(context).close(result);
      return;
    }
    setState(() {});
  }

  void close([Object? result]) {
    for (final _Route route in _routes) {
      if (!route.completer.isCompleted) route.completer.complete(null);
    }
    _routes.clear();
    ConsoleRuntime.of(context).close(result);
  }

  @override
  Widget build(BuildContext context) =>
      _Overlay(screens: <Widget>[for (final _Route route in _routes) route.screen], visible: _routes.length - 1);
}

class _Route {
  _Route(this.screen);

  final Widget screen;
  final Completer<Object?> completer = Completer<Object?>();
}

class _Overlay extends RenderWidget {
  const _Overlay({required this.screens, required this.visible});

  final List<Widget> screens;
  final int visible;

  @override
  List<Widget> get children => screens;

  @override
  bool paintsChild(int index) => index == visible;

  @override
  Frame paint(Constraints constraints, List<Frame> children) => visible < 0 ? const Frame.empty() : children[visible];
}
