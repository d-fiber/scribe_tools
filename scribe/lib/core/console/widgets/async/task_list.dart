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

import '../../framework/framework.dart';
import '../layout/column.dart';
import '../layout/row.dart';
import '../text/text.dart';
import 'builders.dart';
import 'spinner.dart';

enum TaskStatus { pending, running, done, failed, skipped }

class TaskStep {
  const TaskStep(this.label, {this.status = TaskStatus.pending, this.detail});

  final String label;
  final TaskStatus status;
  final String? detail;

  TaskStep copyWith({TaskStatus? status, String? detail}) =>
      TaskStep(label, status: status ?? this.status, detail: detail ?? this.detail);
}

class TaskRunner extends ChangeNotifier {
  TaskRunner(List<String> labels) : steps = <TaskStep>[for (final String label in labels) TaskStep(label)];

  final List<TaskStep> steps;

  bool get isDone => steps.every((TaskStep step) => step.status != TaskStatus.pending);

  bool get hasFailure => steps.any((TaskStep step) => step.status == TaskStatus.failed);

  Future<T> run<T>(int index, FutureOr<T> Function() body) async {
    _set(index, TaskStatus.running);
    try {
      final T outcome = await body();
      _set(index, TaskStatus.done);
      return outcome;
    } on Object catch (error) {
      _set(index, TaskStatus.failed, detail: '$error');
      rethrow;
    }
  }

  void skip(int index, {String? detail}) => _set(index, TaskStatus.skipped, detail: detail);

  void succeed(int index, {String? detail}) => _set(index, TaskStatus.done, detail: detail);

  void fail(int index, {String? detail}) => _set(index, TaskStatus.failed, detail: detail);

  void _set(int index, TaskStatus status, {String? detail}) {
    if (index < 0 || index >= steps.length) return;

    steps[index] = steps[index].copyWith(status: status, detail: detail);
    notifyListeners();
  }
}

class TaskList extends StatelessWidget {
  const TaskList({required this.steps, super.key});

  TaskList.of(TaskRunner runner, {super.key}) : steps = runner.steps;

  final List<TaskStep> steps;

  @override
  Widget build(BuildContext context) => Column(children: <Widget>[for (final TaskStep step in steps) _TaskLine(step)]);
}

class TaskListView extends StatelessWidget {
  const TaskListView({required this.runner, super.key});

  final TaskRunner runner;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runner,
    builder: (BuildContext context) => TaskList(steps: runner.steps),
  );
}

class _TaskLine extends StatelessWidget {
  const _TaskLine(this.step);

  final TaskStep step;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final ProgressStyle style = theme.styles.progress;
    final String? detail = step.detail;

    return Row(
      children: <Widget>[
        if (step.status == TaskStatus.running) const Spinner() else Text(_mark(style), color: _color(theme)),
        const Text(' '),
        Text(step.label, color: _label(theme)),
        if (detail != null) ...<Widget>[const Text(' '), Text(detail, color: theme.colors.text.tertiary)],
      ],
    );
  }

  String _mark(ProgressStyle style) => switch (step.status) {
    TaskStatus.pending => style.pending,
    TaskStatus.running => style.pending,
    TaskStatus.done => style.done,
    TaskStatus.failed => style.failed,
    TaskStatus.skipped => style.skipped,
  };

  Color _color(ConsoleTheme theme) => switch (step.status) {
    TaskStatus.pending => theme.colors.text.placeholder,
    TaskStatus.running => theme.colors.action.primary,
    TaskStatus.done => theme.colors.feedback.success,
    TaskStatus.failed => theme.colors.feedback.error,
    TaskStatus.skipped => theme.colors.text.tertiary,
  };

  Color _label(ConsoleTheme theme) => switch (step.status) {
    TaskStatus.pending => theme.colors.text.placeholder,
    TaskStatus.skipped => theme.colors.text.tertiary,
    _ => theme.colors.text.primary,
  };
}
