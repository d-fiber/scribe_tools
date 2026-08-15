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

import 'package:scribe/core/console/console.dart';
import 'package:scribe/core/console/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('future builder', () {
    test('shows the waiting state then the value', () async {
      final Completer<String> completer = Completer<String>();
      final ConsoleTester tester = ConsoleTester(
        FutureBuilder<String>(
          future: completer.future,
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) =>
              Text(snapshot.isWaiting ? 'loading' : snapshot.data ?? 'none'),
        ),
      );
      await tester.pump();
      expect(tester.lines, <String>['loading']);

      completer.complete('ready');
      await tester.pump();
      expect(tester.lines, <String>['ready']);

      await tester.close();
    });

    test('surfaces failures through the snapshot', () async {
      final Completer<String> completer = Completer<String>();
      final ConsoleTester tester = ConsoleTester(
        FutureBuilder<String>(
          future: completer.future,
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) =>
              Text(snapshot.hasError ? 'failed' : 'pending'),
        ),
      );
      await tester.pump();

      completer.completeError(StateError('nope'), StackTrace.empty);
      await tester.pump();

      expect(tester.lines, <String>['failed']);
      await tester.close();
    });
  });

  group('stream builder', () {
    test('rebuilds on every event', () async {
      final StreamController<int> controller = StreamController<int>();
      final ConsoleTester tester = ConsoleTester(
        StreamBuilder<int>(
          stream: controller.stream,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) => Text('${snapshot.data ?? 0}'),
        ),
      );
      await tester.pump();

      controller.add(1);
      await tester.pump();
      expect(tester.lines, <String>['1']);

      controller.add(2);
      await tester.pump();
      expect(tester.lines, <String>['2']);

      await controller.close();
      await tester.close();
    });
  });

  group('progress', () {
    test('fills the bar proportionally', () {
      expect(renderToLines(const ProgressBar(value: 5, total: 10, width: 10)), <String>['█████░░░░░  50%']);
    });

    test('clamps out of range values', () {
      expect(renderToLines(const ProgressBar(value: 12, total: 10, width: 4)), <String>['████ 100%']);
    });
  });

  group('tasks', () {
    test('renders one line per step with its status', () {
      expect(
        renderToLines(
          const TaskList(
            steps: <TaskStep>[
              TaskStep('pull', status: TaskStatus.done),
              TaskStep('build'),
              TaskStep('push', status: TaskStatus.failed, detail: 'denied'),
            ],
          ),
        ),
        <String>['✔ pull', '○ build', '✖ push denied'],
      );
    });

    test('follows the runner as steps complete', () async {
      final TaskRunner runner = TaskRunner(<String>['first', 'second']);
      final ConsoleTester tester = ConsoleTester(TaskListView(runner: runner));
      await tester.pump();
      expect(tester.lines, <String>['○ first', '○ second']);

      await runner.run(0, () async {});
      await tester.pump();
      expect(tester.lines.first, '✔ first');
      expect(runner.hasFailure, isFalse);

      await expectLater(runner.run(1, () async => throw StateError('down')), throwsStateError);
      await tester.pump();
      expect(tester.lines.last, contains('✖ second'));
      expect(runner.hasFailure, isTrue);

      await tester.close();
    });
  });

  group('logs', () {
    test('keeps the last lines of the stream', () async {
      final StreamController<String> controller = StreamController<String>();
      final ConsoleTester tester = ConsoleTester(LogView(stream: controller.stream, height: 2));
      await tester.pump();

      controller
        ..add('one')
        ..add('two')
        ..add('three');
      await tester.pump();

      expect(tester.lines, <String>['two', 'three']);

      await controller.close();
      await tester.close();
    });
  });

  group('spinner', () {
    test('advances on every tick', () async {
      final ConsoleTester tester = ConsoleTester(const Spinner(label: 'working', interval: Duration(milliseconds: 5)));
      await tester.pump();
      final String first = tester.text;

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();

      expect(tester.text, isNot(first));
      expect(tester.text, contains('working'));

      await tester.close();
    });
  });
}
