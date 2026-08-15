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

typedef WidgetBuilder = Widget Function(BuildContext context);

typedef KeyHandler = bool Function(KeyEvent event);

typedef PointerHandler = bool Function(MouseEvent event);

abstract interface class BuildContext {
  Widget get widget;

  bool get mounted;

  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>();

  T? findAncestorWidgetOfExactType<T extends Widget>();

  T? findAncestorStateOfType<T extends State<StatefulWidget>>();

  void visitAncestors(bool Function(Widget widget) visitor);
}

class ValueKey<T> {
  const ValueKey(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is ValueKey<T> && other.value == value;

  @override
  int get hashCode => Object.hash(ValueKey<T>, value);

  @override
  String toString() => 'ValueKey($value)';
}

class GlobalKey<T extends State<StatefulWidget>> {
  Element? _element;

  BuildContext? get currentContext => _element;

  Widget? get currentWidget => _element?.widget;

  T? get currentState {
    final Element? element = _element;
    return element is StatefulElement && element.state is T ? element.state as T : null;
  }
}

abstract class Widget {
  const Widget({this.key});

  final Object? key;

  Element createElement();

  static bool canUpdate(Widget current, Widget next) =>
      current.runtimeType == next.runtimeType && current.key == next.key;
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);

  @override
  Element createElement() => StatelessElement(this);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});

  State<StatefulWidget> createState();

  @override
  Element createElement() => StatefulElement(this);
}

abstract class InheritedWidget extends Widget {
  const InheritedWidget({required this.child, super.key});

  final Widget child;

  bool updateShouldNotify(covariant InheritedWidget previous);

  @override
  Element createElement() => InheritedElement(this);
}

abstract class RenderWidget extends Widget {
  const RenderWidget({super.key});

  List<Widget> get children => const <Widget>[];

  bool paintsChild(int index) => true;

  Constraints constrainChild(int index, Constraints constraints) => constraints;

  Frame layout(Constraints constraints, ChildPainter children) => compose(constraints, <Frame>[
    for (int index = 0; index < children.length; index++)
      paintsChild(index) ? children.paint(index, constrainChild(index, constraints)) : const Frame.empty(),
  ], children);

  Frame compose(Constraints constraints, List<Frame> children, ChildPainter? geometry) => paint(constraints, children);

  Frame paint(Constraints constraints, List<Frame> children);

  @override
  Element createElement() => RenderElement(this);
}

class Builder extends StatelessWidget {
  const Builder(this.builder, {super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

class ErrorWidget extends RenderWidget {
  const ErrorWidget(this.error, {super.key});

  final Object error;

  @override
  Frame paint(Constraints constraints, List<Frame> children) => Frame.text(Colors.brightRed.paint('■ $error'));
}

abstract class State<W extends StatefulWidget> {
  late StatefulElement _element;
  late W _widget;

  W get widget => _widget;

  BuildContext get context => _element;

  bool get mounted => _element.mounted;

  void initState() {}

  void didChangeDependencies() {}

  void didUpdateWidget(W previous) {}

  void dispose() {}

  void setState(void Function() update) {
    update();
    _element.markNeedsBuild();
  }

  Widget build(BuildContext context);
}
