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

class _Menu extends StatefulWidget {
  const _Menu({this.header = true});

  final bool header;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  int _selected = 0;
  int _submitted = -1;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      if (widget.header) const Text('header'),
      SelectableList(
        items: const <Widget>[Text('alpha'), Text('beta'), Text('gamma')],
        height: 3,
        onChanged: (int index) => setState(() => _selected = index),
        onSubmit: (int index) => setState(() => _submitted = index),
      ),
      Text('picked:$_selected chosen:$_submitted'),
    ],
  );
}

void main() {
  group('keyboard', () {
    test('moves the selection with the arrow keys', () async {
      final ConsoleTester tester = ConsoleTester(const _Menu(header: false));
      await tester.pump();
      expect(tester.lines.first, '❯ alpha');

      await tester.sendControl(ControlCharacter.arrowDown);
      expect(tester.lines[1], '❯ beta');
      expect(tester.lines.last, 'picked:1 chosen:-1');

      await tester.sendControl(ControlCharacter.enter);
      expect(tester.lines.last, 'picked:1 chosen:1');

      await tester.close();
    });

    test('wraps around at the end of the list', () async {
      final ConsoleTester tester = ConsoleTester(const _Menu(header: false));
      await tester.pump();

      await tester.sendControl(ControlCharacter.arrowUp);
      expect(tester.lines.last, 'picked:2 chosen:-1');

      await tester.close();
    });

    test('edits a text field character by character', () async {
      final ConsoleTester tester = ConsoleTester(const TextInput(label: 'name'));
      await tester.pump();

      await tester.sendText('abc');
      expect(tester.lines.first, contains('name: abc'));

      await tester.sendControl(ControlCharacter.backspace);
      expect(tester.lines.first, contains('name: ab'));

      await tester.close();
    });
  });

  group('pointer', () {
    test('routes the wheel to the list under the cursor', () async {
      final ConsoleTester tester = ConsoleTester(const _Menu());
      await tester.pump();
      expect(tester.lines.last, 'picked:0 chosen:-1');

      await tester.sendMouse(column: 1, row: 3, button: MouseButton.wheelDown);
      expect(tester.lines.last, 'picked:1 chosen:-1');

      await tester.close();
    });

    test('ignores the wheel outside the list', () async {
      final ConsoleTester tester = ConsoleTester(const _Menu());
      await tester.pump();

      await tester.sendMouse(column: 1, row: 1, button: MouseButton.wheelDown);
      expect(tester.lines.last, 'picked:0 chosen:-1');

      await tester.close();
    });
  });
}
