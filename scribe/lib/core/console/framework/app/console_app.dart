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

import '../framework.dart';
import 'navigator.dart';

class ConsoleApp extends StatefulWidget {
  const ConsoleApp({
    required this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.onUnknownRoute,
    this.fullscreen = false,
    this.mouse = false,
    this.title,
    this.theme,
    this.brightness,
    super.key,
  }) : initialRoute = null;

  const ConsoleApp.routed({
    required this.routes,
    required this.initialRoute,
    this.onUnknownRoute,
    this.fullscreen = false,
    this.mouse = false,
    this.title,
    this.theme,
    this.brightness,
    super.key,
  }) : home = null;

  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onUnknownRoute;
  final bool fullscreen;
  final bool mouse;
  final String? title;
  final ConsoleTheme? theme;
  final Brightness? brightness;

  @override
  State<ConsoleApp> createState() => _ConsoleAppState();
}

class _ConsoleAppState extends State<ConsoleApp> {
  ConsoleRuntime? _runtime;

  @override
  void didChangeDependencies() {
    final ConsoleRuntime? runtime = ConsoleRuntime.maybeOf(context);
    if (identical(runtime, _runtime)) return;

    _runtime?.colors.removeListener(_refresh);
    _runtime = runtime;
    runtime?.colors.addListener(_refresh);
    _apply();
  }

  @override
  void didUpdateWidget(ConsoleApp previous) {
    if (previous.fullscreen != widget.fullscreen || previous.mouse != widget.mouse || previous.title != widget.title) {
      _apply();
    }
  }

  @override
  void dispose() => _runtime?.colors.removeListener(_refresh);

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme(),
    child: Navigator(home: _home(), routes: widget.routes, onUnknownRoute: widget.onUnknownRoute),
  );

  ConsoleTheme _theme() {
    final ConsoleTheme? given = widget.theme;
    if (given != null) return given;

    final Brightness? forced = widget.brightness;
    if (forced != null) return ConsoleTheme(colors: ConsoleColors.forBrightness(forced));

    return ConsoleTheme(colors: _runtime?.colors.value ?? ConsoleColors.detected);
  }

  void _refresh() => setState(() {});

  void _apply() {
    final ConsoleRuntime? runtime = _runtime;
    if (runtime == null) return;

    runtime.setFullscreen(widget.fullscreen);
    runtime.setMouse(widget.mouse);

    final String? title = widget.title;
    if (title != null) runtime.setTitle(title);
  }

  Widget _home() {
    final Widget? home = widget.home;
    if (home != null) return home;

    return resolveRoute(widget.initialRoute ?? '/', widget.routes, widget.onUnknownRoute);
  }
}
