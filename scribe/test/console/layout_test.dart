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

void main() {
  group('frame', () {
    test('measures ansi sequences as invisible', () {
      expect(visibleWidth(Colors.red.paint('abc')), 3);
      expect(stripAnsi(Colors.red.paint('abc')), 'abc');
    });

    test('measures wide runes as two columns', () {
      expect(visibleWidth('東京'), 4);
      expect(visibleWidth('a東b'), 4);
      expect(visibleWidth('é'), 1);
    });

    test('pads to the visible width', () {
      expect(stripAnsi(padVisible(Colors.red.paint('ab'), 5)), 'ab   ');
      expect(padVisible('東', 4), '東  ');
    });
  });

  group('column', () {
    test('stacks children in order', () {
      expect(renderToLines(const Column(children: <Widget>[Text('one'), Text('two')])), <String>['one', 'two']);
    });

    test('aligns children on the cross axis', () {
      expect(
        renderToLines(
          const Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[Text('a'), Text('long')]),
        ),
        <String>['   a', 'long'],
      );
    });

    test('spreads children when the height is bounded', () {
      expect(
        renderToLines(
          const Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[Text('a'), Text('b')],
          ),
          height: 4,
        ),
        <String>['a', '', '', 'b'],
      );
    });
  });

  group('row', () {
    test('places children beside each other', () {
      expect(renderToLines(const Row(children: <Widget>[Text('ab'), Text('cd')])), <String>['abcd']);
    });

    test('inserts the separator between children', () {
      expect(
        renderToLines(const Row(separator: Text('|'), children: <Widget>[Text('a'), Text('b'), Text('c')])),
        <String>['a|b|c'],
      );
    });

    test('gives expanded children the free space', () {
      expect(
        renderToLines(
          const Row(
            children: <Widget>[
              Text('a'),
              Expanded(child: Text('b')),
            ],
          ),
          width: 6,
        ),
        <String>['ab    '],
      );
    });
  });

  group('box', () {
    test('pads its child', () {
      expect(renderToLines(const Padding(padding: EdgeInsets.all(1), child: Text('x'))), <String>['   ', ' x ', '   ']);
    });

    test('draws a border around its child', () {
      expect(renderToLines(const Container(border: Border(), child: Text('ok'))), <String>['┌──┐', '│ok│', '└──┘']);
    });

    test('sizes a box to the requested width', () {
      expect(renderToLines(const SizedBox(width: 4, height: 2, child: Text('x'))), <String>['x   ', '    ']);
    });

    test('centers its child inside the available space', () {
      expect(renderToLines(const SizedBox(width: 5, height: 3, child: Center(child: Text('x'))), width: 5), <String>[
        '     ',
        '  x  ',
        '     ',
      ]);
    });
  });

  group('theme', () {
    test('resolves the border colour from the ambient theme', () {
      const ConsoleTheme theme = ConsoleTheme(colors: ConsoleColors.light);
      final List<String> painted = renderToLines(
        const Theme(
          data: theme,
          child: Container(border: Border(), child: Text('x')),
        ),
      );

      expect(painted.first, '┌─┐');
    });

    test('falls back to the detected palette without a theme', () {
      expect(renderToLines(const Container(border: Border(), child: Text('x'))).first, '┌─┐');
    });
  });
}
