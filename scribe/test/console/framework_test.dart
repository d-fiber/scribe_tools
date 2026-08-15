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

import 'package:scribe/core/console/console.dart';
import 'package:scribe/core/console/testing/testing.dart';
import 'package:test/test.dart';

final List<String> _mounted = <String>[];
final List<String> _disposed = <String>[];

class _Item extends StatefulWidget {
  const _Item(this.id, {super.key});

  final String id;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  int _hits = 0;

  @override
  void initState() => _mounted.add(widget.id);

  @override
  void dispose() => _disposed.add(widget.id);

  void hit() => setState(() => _hits++);

  @override
  Widget build(BuildContext context) => Text('${widget.id}:$_hits');
}

class _Host extends StatefulWidget {
  const _Host({required this.initial, super.key});

  final List<String> initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> _order = widget.initial;

  static final Map<String, GlobalKey<_ItemState>> handles = <String, GlobalKey<_ItemState>>{};

  void reorder(List<String> next) => setState(() => _order = next);

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      for (final String id in _order) _Item(id, key: handles.putIfAbsent(id, GlobalKey<_ItemState>.new)),
    ],
  );
}

class _Failing extends StatelessWidget {
  const _Failing();

  @override
  Widget build(BuildContext context) => throw StateError('boom');
}

class _Watcher extends StatefulWidget {
  const _Watcher();

  @override
  State<_Watcher> createState() => _WatcherState();
}

class _WatcherState extends State<_Watcher> {
  int _changes = 0;

  @override
  void didChangeDependencies() => _changes++;

  @override
  Widget build(BuildContext context) => Text('${ConsoleTheme.of(context).colors.brightness.name}:$_changes');
}

class _ThemeSwitch extends StatefulWidget {
  const _ThemeSwitch();

  @override
  State<_ThemeSwitch> createState() => _ThemeSwitchState();
}

class _ThemeSwitchState extends State<_ThemeSwitch> {
  ConsoleColors _colors = ConsoleColors.dark;

  static _ThemeSwitchState? current;

  @override
  void initState() => current = this;

  void toggle() => setState(() => _colors = ConsoleColors.light);

  @override
  Widget build(BuildContext context) => Theme(
    data: ConsoleTheme(colors: _colors),
    child: const _Watcher(),
  );
}

void main() {
  setUp(() {
    _mounted.clear();
    _disposed.clear();
    _HostState.handles.clear();
    _ThemeSwitchState.current = null;
  });

  group('reconciliation', () {
    test('keeps element state when keyed children are reordered', () async {
      final GlobalKey<_HostState> host = GlobalKey<_HostState>();
      final ConsoleTester tester = ConsoleTester(_Host(initial: const <String>['a', 'b', 'c'], key: host));
      await tester.pump();

      expect(_mounted, <String>['a', 'b', 'c']);

      _HostState.handles['b']!.currentState!.hit();
      await tester.pump();
      expect(tester.lines, <String>['a:0', 'b:1', 'c:0']);

      host.currentState!.reorder(<String>['c', 'b', 'a']);
      await tester.pump();

      expect(_mounted, <String>['a', 'b', 'c']);
      expect(_disposed, isEmpty);
      expect(tester.lines, <String>['c:0', 'b:1', 'a:0']);

      await tester.close();
    });

    test('disposes children that disappear', () async {
      final GlobalKey<_HostState> host = GlobalKey<_HostState>();
      final ConsoleTester tester = ConsoleTester(_Host(initial: const <String>['a', 'b'], key: host));
      await tester.pump();

      host.currentState!.reorder(<String>['b']);
      await tester.pump();

      expect(_disposed, <String>['a']);
      expect(tester.lines, <String>['b:0']);

      await tester.close();
    });
  });

  group('lifecycle', () {
    test('runs initState before the first build', () async {
      final ConsoleTester tester = ConsoleTester(const _Host(initial: <String>['solo']));
      await tester.pump();

      expect(_mounted, <String>['solo']);
      await tester.close();
    });

    test('notifies dependants when an inherited widget changes', () async {
      final ConsoleTester tester = ConsoleTester(const _ThemeSwitch());
      await tester.pump();
      expect(tester.lines, <String>['dark:1']);

      _ThemeSwitchState.current!.toggle();
      await tester.pump();
      expect(tester.lines, <String>['light:2']);

      await tester.close();
    });
  });

  group('errors', () {
    test('renders a build failure instead of corrupting the terminal', () async {
      final ConsoleTester tester = ConsoleTester(const _Failing());
      await tester.pump();

      expect(tester.text, contains('boom'));
      expect(tester.surface.stopped, isFalse);

      await expectLater(tester.close(), throwsStateError);
      expect(tester.surface.stopped, isTrue);
    });
  });
}
