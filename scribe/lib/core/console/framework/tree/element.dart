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

abstract class Element implements BuildContext {
  Element(this._widget);

  Widget _widget;
  Element? _parent;
  BuildOwner? _owner;
  Map<Type, InheritedElement>? _inherited;
  Set<InheritedElement>? _dependencies;
  int _depth = 0;
  bool _mounted = false;
  bool _dirty = true;

  @override
  Widget get widget => _widget;

  @override
  bool get mounted => _mounted;

  BuildOwner get owner => _owner!;

  int get depth => _depth;

  void mount(Element? parent, BuildOwner owner) {
    _parent = parent;
    _owner = owner;
    _depth = parent == null ? 0 : parent._depth + 1;
    _mounted = true;
    _inherited = inheritedFor(parent);

    final Object? key = widget.key;
    if (key is GlobalKey) key._element = this;
  }

  Map<Type, InheritedElement>? inheritedFor(Element? parent) => parent?._inherited;

  void update(Widget next) => _widget = next;

  void unmount() {
    visitChildren((Element child) => child.unmount());
    _releaseDependencies();
    _mounted = false;

    final Object? key = widget.key;
    if (key is GlobalKey && key._element == this) key._element = null;
  }

  void visitChildren(void Function(Element child) visitor) {}

  Frame paint(Painter painter, Constraints constraints);

  void rebuildNow() {
    _dirty = true;
    rebuild();
  }

  void markNeedsBuild() {
    if (_dirty || !_mounted) return;
    _dirty = true;
    owner.scheduleBuild(this);
  }

  void rebuild() {
    if (!_dirty || !_mounted) return;
    _dirty = false;
    performRebuild();
  }

  void performRebuild() {}

  void didChangeDependencies() => markNeedsBuild();

  Element? updateChild(Element? child, Widget? next) {
    if (next == null) {
      child?.unmount();
      return null;
    }
    if (child != null && Widget.canUpdate(child.widget, next)) {
      child.update(next);
      return child;
    }
    child?.unmount();
    final Element created = next.createElement();
    created.mount(this, owner);
    return created;
  }

  List<Element> updateChildren(List<Element> current, List<Widget> next) {
    final Map<Object, Element> keyed = <Object, Element>{};
    final List<Element> free = <Element>[];
    for (final Element child in current) {
      final Object? key = child.widget.key;
      if (key == null) {
        free.add(child);
        continue;
      }
      keyed[key] = child;
    }

    final List<Element> updated = <Element>[];
    final Set<Element> reused = <Element>{};
    int cursor = 0;

    for (final Widget widget in next) {
      Element? match;
      if (widget.key != null) {
        match = _takeKeyed(keyed, widget);
      } else if (cursor < free.length) {
        final Element candidate = free[cursor];
        cursor++;
        if (Widget.canUpdate(candidate.widget, widget)) match = candidate;
      }

      if (match != null) {
        reused.add(match);
        match.update(widget);
        updated.add(match);
        continue;
      }

      final Element created = widget.createElement();
      created.mount(this, owner);
      updated.add(created);
    }

    for (final Element child in current) {
      if (!reused.contains(child)) child.unmount();
    }
    return updated;
  }

  Element? _takeKeyed(Map<Object, Element> keyed, Widget widget) {
    final Element? candidate = keyed[widget.key];
    if (candidate == null || !Widget.canUpdate(candidate.widget, widget)) return null;

    keyed.remove(widget.key);
    return candidate;
  }

  void _releaseDependencies() {
    final Set<InheritedElement>? dependencies = _dependencies;
    if (dependencies == null) return;

    for (final InheritedElement dependency in dependencies) {
      dependency._dependents.remove(this);
    }
    dependencies.clear();
  }

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>() {
    final InheritedElement? ancestor = _inherited?[T];
    if (ancestor == null) return null;

    (_dependencies ??= <InheritedElement>{}).add(ancestor);
    ancestor._dependents.add(this);

    return ancestor.widget as T;
  }

  @override
  T? findAncestorWidgetOfExactType<T extends Widget>() {
    T? found;
    visitAncestors((Widget widget) {
      if (widget is! T) return true;
      found = widget;
      return false;
    });
    return found;
  }

  @override
  T? findAncestorStateOfType<T extends State<StatefulWidget>>() {
    Element? ancestor = _parent;
    while (ancestor != null) {
      final Element current = ancestor;
      if (current is StatefulElement && current.state is T) return current.state as T;
      ancestor = current._parent;
    }
    return null;
  }

  @override
  void visitAncestors(bool Function(Widget widget) visitor) {
    Element? ancestor = _parent;
    while (ancestor != null && visitor(ancestor.widget)) {
      ancestor = ancestor._parent;
    }
  }
}

abstract class ComponentElement extends Element {
  ComponentElement(super.widget);

  Element? _child;

  Widget build();

  @override
  void mount(Element? parent, BuildOwner owner) {
    super.mount(parent, owner);
    rebuild();
  }

  @override
  void update(Widget next) {
    super.update(next);
    _dirty = true;
    rebuild();
  }

  @override
  void performRebuild() {
    _releaseDependencies();
    _child = updateChild(_child, _buildSafely());
  }

  Widget _buildSafely() {
    try {
      return build();
    } on Object catch (error, stack) {
      owner.reportError(error, stack);
      return ErrorWidget(error);
    }
  }

  @override
  void visitChildren(void Function(Element child) visitor) {
    final Element? child = _child;
    if (child != null) visitor(child);
  }

  @override
  Frame paint(Painter painter, Constraints constraints) => _child?.paint(painter, constraints) ?? const Frame.empty();
}

class StatelessElement extends ComponentElement {
  StatelessElement(StatelessWidget super.widget);

  @override
  Widget build() => (widget as StatelessWidget).build(this);
}

class InheritedElement extends ComponentElement {
  InheritedElement(InheritedWidget super.widget);

  final Set<Element> _dependents = <Element>{};

  @override
  Map<Type, InheritedElement> inheritedFor(Element? parent) => <Type, InheritedElement>{
    ...?parent?._inherited,
    widget.runtimeType: this,
  };

  @override
  Widget build() => (widget as InheritedWidget).child;

  @override
  void update(Widget next) {
    final InheritedWidget previous = widget as InheritedWidget;
    super.update(next);
    if ((next as InheritedWidget).updateShouldNotify(previous)) _notifyDependents();
  }

  void _notifyDependents() {
    for (final Element dependent in _dependents.toList()) {
      if (dependent.mounted) dependent.didChangeDependencies();
    }
  }
}

class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget widget) : state = widget.createState(), super(widget) {
    state._element = this;
    state._widget = widget;
  }

  final State<StatefulWidget> state;

  bool _started = false;

  @override
  void mount(Element? parent, BuildOwner owner) {
    _parent = parent;
    _owner = owner;
    _depth = parent == null ? 0 : parent._depth + 1;
    _mounted = true;
    _inherited = inheritedFor(parent);

    final Object? key = widget.key;
    if (key is GlobalKey) key._element = this;

    _start();
    rebuild();
  }

  void _start() {
    if (_started) return;
    _started = true;
    state.initState();
    state.didChangeDependencies();
  }

  @override
  Widget build() {
    _start();
    return state.build(this);
  }

  @override
  void update(Widget next) {
    final StatefulWidget previous = state._widget;
    _widget = next;
    state._widget = next as StatefulWidget;
    _dirty = true;
    state.didUpdateWidget(previous);
    rebuild();
  }

  @override
  void didChangeDependencies() {
    state.didChangeDependencies();
    markNeedsBuild();
  }

  @override
  void unmount() {
    super.unmount();
    state.dispose();
  }
}

class RenderElement extends Element {
  RenderElement(RenderWidget super.widget);

  List<Element> _children = const <Element>[];

  RenderWidget get renderWidget => widget as RenderWidget;

  @override
  void mount(Element? parent, BuildOwner owner) {
    super.mount(parent, owner);
    _dirty = false;
    _updateChildren();
  }

  @override
  void update(Widget next) {
    super.update(next);
    _updateChildren();
  }

  void _updateChildren() => _children = updateChildren(_children, renderWidget.children);

  @override
  void visitChildren(void Function(Element child) visitor) => _children.forEach(visitor);

  @override
  Frame paint(Painter painter, Constraints constraints) {
    try {
      return renderWidget.layout(constraints, ChildPainter(_children, painter));
    } on Object catch (error, stack) {
      owner.reportError(error, stack);
      return Frame.text(Colors.brightRed.paint('■ $error'));
    }
  }
}

class ChildPainter {
  ChildPainter(this._children, this._painter);

  final List<Element> _children;
  final Painter _painter;
  final List<PaintedRange> _ranges = <PaintedRange>[];

  int get length => _children.length;

  Frame paint(int index, Constraints constraints) {
    final int start = _painter.length;
    final Frame frame = _children[index].paint(_painter, constraints);
    _ranges.add(PaintedRange(index, start, _painter.length));

    return frame;
  }

  void translate(int index, int dx, int dy) {
    if (dx == 0 && dy == 0) return;

    for (final PaintedRange range in _ranges) {
      if (range.index != index) continue;
      _painter.translate(range.start, range.end, dx, dy);
    }
  }
}

class PaintedRange {
  const PaintedRange(this.index, this.start, this.end);

  final int index;
  final int start;
  final int end;
}
