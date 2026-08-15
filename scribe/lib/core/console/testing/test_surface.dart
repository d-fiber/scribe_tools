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

import '../framework/framework.dart';

class TestSurface implements ConsoleSurface {
  TestSurface({this.columns = 80, int? viewportHeight, this.brightness}) : _viewport = viewportHeight;

  @override
  final int columns;

  final Brightness? brightness;

  final List<Frame> frames = <Frame>[];

  int? _viewport;
  bool _fullscreen = false;
  bool _mouse = false;
  bool _started = false;
  bool _stopped = false;
  String? _title;

  final List<ConsoleEvent> _pending = <ConsoleEvent>[];
  Completer<ConsoleEvent?>? _waiting;

  @override
  void Function()? onResize;

  @override
  void Function(Brightness brightness)? onBrightness;

  bool get started => _started;

  bool get stopped => _stopped;

  String? get title => _title;

  Frame get frame => frames.isEmpty ? const Frame.empty() : frames.last;

  List<String> get lines => <String>[for (final String line in frame.lines) stripAnsi(line)];

  String get text => lines.join('\n');

  @override
  int? get viewportHeight => _viewport;

  @override
  int get originRow => 1;

  @override
  bool get fullscreen => _fullscreen;

  @override
  set fullscreen(bool value) => _fullscreen = value;

  @override
  bool get mouse => _mouse;

  @override
  set mouse(bool value) => _mouse = value;

  @override
  void setTitle(String title) => _title = title;

  @override
  void start() => _started = true;

  @override
  void stop() => _stopped = true;

  @override
  void draw(Frame frame) => frames.add(frame);

  @override
  void erase() => frames.clear();

  @override
  Future<Brightness?> queryBrightness() async => brightness;

  @override
  Future<void> locate() async {}

  @override
  Future<void> relocate() async {}

  @override
  Future<ConsoleEvent?> nextEvent() {
    if (_pending.isNotEmpty) return Future<ConsoleEvent?>.value(_pending.removeAt(0));

    final Completer<ConsoleEvent?> waiting = Completer<ConsoleEvent?>();
    _waiting = waiting;

    return waiting.future;
  }

  @override
  void interrupt() {
    final Completer<ConsoleEvent?>? waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete(null);
  }

  void push(ConsoleEvent event) {
    _pending.add(event);

    final Completer<ConsoleEvent?>? waiting = _waiting;
    if (waiting == null || waiting.isCompleted) return;

    _waiting = null;
    waiting.complete(_pending.removeAt(0));
  }

  void resize({int? viewportHeight}) {
    _viewport = viewportHeight ?? _viewport;
    onResize?.call();
  }

  void changeBrightness(Brightness value) => onBrightness?.call(value);
}
