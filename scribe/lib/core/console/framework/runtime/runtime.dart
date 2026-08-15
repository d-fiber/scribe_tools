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

Future<T?> runConsole<T>(Widget app, {ConsoleSurface? surface}) => ConsoleRuntime(surface ?? Terminal()).run<T>(app);

void renderConsole(Widget app, {Stdout? output}) => ConsoleRuntime(Terminal(output: output)).render(app);

class BuildOwner {
  BuildOwner(this.onScheduleBuild, {this.onError});

  final VoidCallback onScheduleBuild;
  final void Function(Object error, StackTrace stack)? onError;

  final List<Element> _dirty = <Element>[];

  void scheduleBuild(Element element) {
    _dirty.add(element);
    onScheduleBuild();
  }

  void reportError(Object error, StackTrace stack) => onError?.call(error, stack);

  void flush() {
    while (_dirty.isNotEmpty) {
      final List<Element> pending = List<Element>.of(_dirty)
        ..sort((Element first, Element second) => first.depth - second.depth);
      _dirty.clear();
      for (final Element element in pending) {
        element.rebuild();
      }
    }
  }
}

class RuntimeScope extends InheritedWidget {
  const RuntimeScope({required this.runtime, required super.child, super.key});

  final ConsoleRuntime runtime;

  @override
  bool updateShouldNotify(RuntimeScope previous) => !identical(runtime, previous.runtime);
}

class ConsoleRuntime {
  ConsoleRuntime(this.surface);

  final ConsoleSurface surface;

  late final BuildOwner owner = BuildOwner(scheduleFrame, onError: _record);

  late final FocusManager focus = FocusManager(scheduleFrame);

  final ValueNotifier<ConsoleColors> colors = ValueNotifier<ConsoleColors>(ConsoleColors.detected);

  Element? _root;
  Painter _painter = Painter();
  bool _frameScheduled = false;
  bool _closed = false;
  Object? _result;
  Object? _error;
  StackTrace? _stack;

  static ConsoleRuntime of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('ConsoleRuntime.of() found no runtime above this widget. Start the tree with runConsole().'));

  static ConsoleRuntime? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RuntimeScope>()?.runtime;

  bool get closed => _closed;

  void close([Object? result]) {
    if (_closed) return;
    _result = result;
    _closed = true;
    surface.interrupt();
  }

  void setMouse(bool value) => surface.mouse = value;

  void setFullscreen(bool value) {
    if (surface.fullscreen == value) return;
    surface.fullscreen = value;
    scheduleFrame();
  }

  void setTitle(String title) => surface.setTitle(title);

  void spawn(FutureOr<void> Function() body) {
    Future<void>.sync(body).catchError(_fail);
  }

  void scheduleFrame() {
    if (_frameScheduled || _closed) return;
    _frameScheduled = true;
    scheduleMicrotask(() {
      _frameScheduled = false;
      if (_closed) return;

      try {
        drawFrame();
      } on Object catch (error, stack) {
        _fail(error, stack);
      }
    });
  }

  void drawFrame() {
    final Element? root = _root;
    if (root == null) return;
    owner.flush();
    if (_closed) return;

    focus.beginFrame();
    final Painter painter = Painter();
    final Frame frame = root.paint(painter, _rootConstraints());
    _painter = painter;
    surface.draw(frame);
  }

  void render(Widget app) {
    final Element root = _mount(app);
    try {
      drawFrame();
    } finally {
      _root = null;
      root.unmount();
    }
  }

  Future<T?> run<T>(Widget app) async {
    surface.onResize = _handleResize;
    surface.onBrightness = applyBrightness;
    surface.start();

    try {
      applyBrightness(await surface.queryBrightness());
      await surface.locate();
      await _loop(app);
    } on Object catch (failure, stack) {
      _record(failure, stack);
    } finally {
      final Element? root = _root;
      _root = null;
      root?.unmount();
      surface.stop();
    }

    final Object? error = _error;
    if (error != null) Error.throwWithStackTrace(error, _stack ?? StackTrace.current);

    return _result as T?;
  }

  Future<void> _loop(Widget app) async {
    _mount(app);
    drawFrame();

    while (!_closed) {
      final ConsoleEvent? event = await surface.nextEvent();
      if (event == null || _closed) return;

      switch (event) {
        case KeyEvent():
          if (event.control == ControlCharacter.ctrlC) return;
          if (_painter.dispatchKey(event, focused: focus.focusedElement)) continue;
          if (event.control != ControlCharacter.tab) continue;
          if (event.shift) {
            focus.previous();
          } else {
            focus.next();
          }
        case MouseEvent():
          _painter.dispatchPointer(_localized(event));
      }
    }
  }

  Element _mount(Widget app) {
    final Element root = RuntimeScope(runtime: this, child: app).createElement();
    _root = root;
    root.mount(null, owner);

    return root;
  }

  MouseEvent _localized(MouseEvent event) => event.at(column: event.column - 1, row: event.row - surface.originRow);

  void applyBrightness(Brightness? brightness) {
    if (brightness == null || colors.value.brightness == brightness) return;

    colors.value = ConsoleColors.forBrightness(brightness);
  }

  Constraints _rootConstraints() {
    final int columns = surface.columns;
    return Constraints(maxWidth: columns > 0 ? columns : null, maxHeight: surface.viewportHeight);
  }

  void _handleResize() {
    scheduleFrame();
    surface.relocate().then((void _) => scheduleFrame()).catchError(_fail);
  }

  void _record(Object error, StackTrace stack) {
    if (_error != null) return;
    _error = error;
    _stack = stack;
  }

  void _fail(Object error, StackTrace stack) {
    _record(error, stack);
    close();
  }
}
