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

import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/terminal.dart';

/// The callback a [Status] runs when it ends.
typedef VoidCallback = void Function();

/// Everything this tool prints, so that no code writes to a stream itself.
///
/// The implementation decides where the text lands and how much of it survives:
/// [StdoutLogger] writes to the terminal, [BufferLogger] keeps it for a test,
/// and a [DelegatingLogger] filters or annotates what passes through it.
abstract class Logger {
  /// Whether [printTrace] reaches the user.
  bool get isVerbose => false;

  /// Whether colour written into a message will be rendered rather than shown raw.
  bool get supportsColor;

  /// Whether the output goes to a terminal rather than a pipe or a file.
  bool get hasTerminal;

  /// The terminal this logger decorates its messages for.
  Terminal get terminal;

  /// Whether [printError] was called at least once.
  ///
  /// The runner reads it after the command returns: a run that printed an error
  /// leaves with a non-zero status even when nothing was thrown.
  bool get hadErrorOutput;

  /// Whether [printWarning] was called at least once.
  bool get hadWarningOutput;

  /// Prints [message] on standard error, and marks the run as having failed.
  void printError(String message, {StackTrace? stackTrace, bool emphasis = false, int indent = 0});

  /// Prints [message] on standard error without marking the run as having failed.
  void printWarning(String message, {bool emphasis = false, int indent = 0});

  /// Prints [message] on standard output.
  ///
  /// Pass `newline: false` to leave the cursor where it stopped, which is what
  /// writing a question needs.
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true});

  /// Prints [message] only when the run is verbose.
  void printTrace(String message);

  /// Starts a labelled unit of work called [message], and returns the [Status] that ends it.
  ///
  /// What the user sees is decided here and not by the caller: a spinner on a
  /// terminal, one summary line when the output is redirected, nothing at all
  /// in a test. Nothing above has to ask whether it is talking to a terminal.
  ///
  /// [timeout] only decides when [Status.seemsSlow] turns true; it never
  /// interrupts anything.
  Status startProgress(String message, {Duration? timeout});

  /// Starts an unlabelled spinner, and returns the [Status] that ends it.
  Status startSpinner({VoidCallback? onFinish});

  /// Erases what was printed last.
  void clear();
}

/// The [Logger] that writes to the terminal the user is watching.
class StdoutLogger extends Logger {
  StdoutLogger({
    required this.terminal,
    required Stdio stdio,
    required OutputPreferences outputPreferences,
    StopwatchFactory stopwatchFactory = const StopwatchFactory(),
  }) : _stdio = stdio,
       _outputPreferences = outputPreferences,
       _stopwatchFactory = stopwatchFactory;

  @override
  final Terminal terminal;

  final Stdio _stdio;
  final OutputPreferences _outputPreferences;
  final StopwatchFactory _stopwatchFactory;

  Status? _status;

  @override
  bool get supportsColor => terminal.supportsColor && _outputPreferences.showColor;

  @override
  bool get hasTerminal => _stdio.hasTerminal;

  @override
  bool hadErrorOutput = false;

  @override
  bool hadWarningOutput = false;

  @override
  void printError(String message, {StackTrace? stackTrace, bool emphasis = false, int indent = 0}) {
    hadErrorOutput = true;
    _writeToStdErr(_decorate(message, emphasis: emphasis, color: TerminalColor.red, indent: indent));
    if (stackTrace != null) _writeToStdErr('$stackTrace\n');
  }

  @override
  void printWarning(String message, {bool emphasis = false, int indent = 0}) {
    hadWarningOutput = true;
    _writeToStdErr(_decorate(message, emphasis: emphasis, color: TerminalColor.yellow, indent: indent));
  }

  @override
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true}) {
    _writeToStdOut(_decorate(message, emphasis: emphasis, color: color, indent: indent, newline: newline));
  }

  @override
  void printTrace(String message) {}

  @override
  Status startProgress(String message, {Duration? timeout}) {
    _stopExisting();

    final Status status = terminal.isAnimationEnabled
        ? SpinnerStatus(
            message: message,
            stopwatch: _stopwatchFactory.createStopwatch(),
            terminal: terminal,
            write: _writeToStdOut,
            onFinish: _clearStatus,
          )
        : SummaryStatus(
            message: message,
            stopwatch: _stopwatchFactory.createStopwatch(),
            write: _writeToStdOut,
            onFinish: _clearStatus,
          );

    _status = status;
    return status..start();
  }

  @override
  Status startSpinner({VoidCallback? onFinish}) {
    _stopExisting();

    final Status status = terminal.isAnimationEnabled
        ? AnonymousSpinnerStatus(
            stopwatch: _stopwatchFactory.createStopwatch(),
            terminal: terminal,
            write: _writeToStdOut,
            onFinish: () {
              _clearStatus();
              onFinish?.call();
            },
          )
        : SilentStatus(stopwatch: _stopwatchFactory.createStopwatch(), onFinish: onFinish);

    _status = status;
    return status..start();
  }

  @override
  void clear() => _writeToStdOut(terminal.clearLines(1));

  void _stopExisting() {
    final Status? running = _status;
    if (running == null) return;
    running.stop();
  }

  void _clearStatus() => _status = null;

  void _writeToStdOut(String message) => _stdio.write(message);

  void _writeToStdErr(String message) => _stdio.writeError(message);

  String _decorate(
    String message,
    {bool emphasis = false,
    TerminalColor? color,
    int indent = 0,
    bool newline = true}
  ) {
    String decorated = message;
    if (emphasis) decorated = terminal.bolden(decorated);
    if (color != null && supportsColor) decorated = terminal.color(decorated, color);
    if (indent > 0) decorated = decorated.split('\n').map((String line) => '${' ' * indent}$line').join('\n');
    return newline ? '$decorated\n' : decorated;
  }
}

/// A [Logger] that keeps every message instead of printing it.
///
/// Messages arrive undecorated: neither colour, emphasis nor indentation is
/// applied, so a test compares plain text.
class BufferLogger extends Logger {
  BufferLogger({Terminal? terminal, this.verbose = false})
    : terminal = terminal ?? TestTerminal();

  @override
  final Terminal terminal;

  /// Whether this logger reports itself as verbose.
  final bool verbose;

  final StringBuffer _error = StringBuffer();
  final StringBuffer _warning = StringBuffer();
  final StringBuffer _status = StringBuffer();
  final StringBuffer _trace = StringBuffer();

  /// Everything passed to [printError], one message per line.
  String get errorText => _error.toString();

  /// Everything passed to [printWarning], one message per line.
  String get warningText => _warning.toString();

  /// Everything passed to [printStatus].
  String get statusText => _status.toString();

  /// Everything passed to [printTrace], whether or not this logger is verbose.
  String get traceText => _trace.toString();

  @override
  bool get isVerbose => verbose;

  @override
  bool get supportsColor => false;

  @override
  bool get hasTerminal => false;

  @override
  bool hadErrorOutput = false;

  @override
  bool hadWarningOutput = false;

  @override
  void printError(String message, {StackTrace? stackTrace, bool emphasis = false, int indent = 0}) {
    hadErrorOutput = true;
    _error.writeln(message);
  }

  @override
  void printWarning(String message, {bool emphasis = false, int indent = 0}) {
    hadWarningOutput = true;
    _warning.writeln(message);
  }

  @override
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true}) {
    if (newline) {
      _status.writeln(message);
    } else {
      _status.write(message);
    }
  }

  @override
  void printTrace(String message) => _trace.writeln(message);

  @override
  Status startProgress(String message, {Duration? timeout}) {
    printStatus(message);
    return SilentStatus(stopwatch: Stopwatch())..start();
  }

  @override
  Status startSpinner({VoidCallback? onFinish}) =>
      SilentStatus(stopwatch: Stopwatch(), onFinish: onFinish)..start();

  /// Empties the four buffers, since there is no line here to erase.
  @override
  void clear() {
    _error.clear();
    _warning.clear();
    _status.clear();
    _trace.clear();
  }
}

/// A [Logger] that forwards every call to another one.
///
/// A subclass overrides only what it changes, which is how `-v` and `-q` are
/// built without either of them knowing where the output ends up.
class DelegatingLogger implements Logger {
  DelegatingLogger(this._delegate);

  final Logger _delegate;

  @override
  bool get isVerbose => _delegate.isVerbose;

  @override
  bool get supportsColor => _delegate.supportsColor;

  @override
  bool get hasTerminal => _delegate.hasTerminal;

  @override
  Terminal get terminal => _delegate.terminal;

  @override
  bool get hadErrorOutput => _delegate.hadErrorOutput;

  @override
  bool get hadWarningOutput => _delegate.hadWarningOutput;

  @override
  void printError(String message, {StackTrace? stackTrace, bool emphasis = false, int indent = 0}) =>
      _delegate.printError(message, stackTrace: stackTrace, emphasis: emphasis, indent: indent);

  @override
  void printWarning(String message, {bool emphasis = false, int indent = 0}) =>
      _delegate.printWarning(message, emphasis: emphasis, indent: indent);

  @override
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true}) =>
      _delegate.printStatus(message, emphasis: emphasis, color: color, indent: indent, newline: newline);

  @override
  void printTrace(String message) => _delegate.printTrace(message);

  @override
  Status startProgress(String message, {Duration? timeout}) => _delegate.startProgress(message, timeout: timeout);

  @override
  Status startSpinner({VoidCallback? onFinish}) => _delegate.startSpinner(onFinish: onFinish);

  @override
  void clear() => _delegate.clear();
}

/// A [DelegatingLogger] that lets traces through and times every message.
///
/// Each line is prefixed with the time since the previous one, so a slow step
/// is visible without measuring anything on purpose. This is what `-v` builds.
class VerboseLogger extends DelegatingLogger {
  VerboseLogger(super.delegate, {StopwatchFactory stopwatchFactory = const StopwatchFactory()})
    : _stopwatch = stopwatchFactory.createStopwatch() {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch;

  @override
  bool get isVerbose => true;

  @override
  void printError(String message, {StackTrace? stackTrace, bool emphasis = false, int indent = 0}) =>
      _emit(_LogType.error, message, stackTrace: stackTrace, indent: indent);

  @override
  void printWarning(String message, {bool emphasis = false, int indent = 0}) =>
      _emit(_LogType.warning, message, indent: indent);

  @override
  void printStatus(String message, {bool emphasis = false, TerminalColor? color, int indent = 0, bool newline = true}) =>
      _emit(_LogType.status, message, indent: indent);

  @override
  void printTrace(String message) => _emit(_LogType.trace, message);

  @override
  Status startProgress(String message, {Duration? timeout}) {
    printStatus(message);
    return SilentStatus(stopwatch: Stopwatch(), onFinish: () => printTrace('$message (done)'))..start();
  }

  void _emit(_LogType type, String message, {StackTrace? stackTrace, int indent = 0}) {
    if (message.trim().isEmpty) return;

    final int millis = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();
    _stopwatch.start();

    final String prefix = millis >= 100 ? '[+${millis}ms] ' : '[   ] ';

    switch (type) {
      case _LogType.error:
        _delegate.printError('$prefix$message', stackTrace: stackTrace, indent: indent);
      case _LogType.warning:
        _delegate.printWarning('$prefix$message', indent: indent);
      case _LogType.status:
        _delegate.printStatus('$prefix$message', indent: indent);
      case _LogType.trace:
        _delegate.printStatus('$prefix$message', color: TerminalColor.grey, indent: indent);
    }
  }
}

enum _LogType { error, warning, status, trace }

/// Where a logger gets the stopwatches it times its output with.
///
/// A test replaces it so the durations printed alongside a [Status] stop
/// depending on how fast the machine is.
class StopwatchFactory {
  const StopwatchFactory();

  /// A new stopwatch, not yet started.
  Stopwatch createStopwatch() => Stopwatch();
}

/// A unit of work being shown to the user while it runs.
///
/// The caller holds it and ends it with [stop] or [cancel]. How much of it is
/// visible is the logger's decision, and ranges from an animated spinner down
/// to nothing at all.
abstract class Status {
  Status({required Stopwatch stopwatch, VoidCallback? onFinish, Duration? timeout})
    : _stopwatch = stopwatch,
      _onFinish = onFinish,
      _timeout = timeout;

  final Stopwatch _stopwatch;
  final VoidCallback? _onFinish;
  final Duration? _timeout;

  /// Whether this status has been running longer than the timeout it was given.
  ///
  /// False when it was given none. Nothing acts on it: it is there for a caller
  /// that wants to say so.
  bool get seemsSlow {
    final Duration? limit = _timeout;
    return limit != null && _stopwatch.elapsed > limit;
  }

  /// The time taken so far, in milliseconds below two seconds and in seconds above.
  String get elapsed {
    final Duration taken = _stopwatch.elapsed;
    if (taken.inSeconds >= 2) return '${(taken.inMilliseconds / 1000).toStringAsFixed(1)}s';
    return '${taken.inMilliseconds}ms';
  }

  /// Starts the clock, and whatever this status shows.
  void start() {
    if (!_stopwatch.isRunning) _stopwatch.start();
  }

  /// Ends this status, reporting how long the work took.
  void stop() => finish();

  /// Ends this status without reporting a time, the work having been given up on.
  void cancel() => finish();

  /// Hides this status so something else can be printed over it.
  void pause() {}

  /// Shows this status again after a [pause].
  void resume() {}

  /// Stops the clock and runs the callback this status was given.
  void finish() {
    if (_stopwatch.isRunning) _stopwatch.stop();
    _onFinish?.call();
  }
}

/// A [Status] that shows nothing and only measures.
class SilentStatus extends Status {
  SilentStatus({required super.stopwatch, super.onFinish});
}

/// A [Status] that prints its message once, then the time it took when it ends.
///
/// This is the shape used when the output is not a terminal, so a log file gets
/// one readable line per step instead of a stream of redrawn frames.
class SummaryStatus extends Status {
  SummaryStatus({
    required this.message,
    required super.stopwatch,
    required this.write,
    super.onFinish,
    super.timeout,
  });

  /// The text naming the work being done.
  final String message;

  /// Where this status writes, so it reaches the user through the logger.
  final void Function(String message) write;

  bool _printed = false;

  @override
  void start() {
    _print();
    super.start();
  }

  @override
  void stop() {
    _print();
    write('$elapsed\n');
    super.stop();
  }

  @override
  void cancel() {
    _print();
    write('\n');
    super.cancel();
  }

  void _print() {
    if (_printed) return;
    _printed = true;
    write('${message.padRight(_kMessageColumns)} ');
  }
}

/// A [Status] that animates a spinner where the cursor stands, with no message.
///
/// The braille frames are replaced by ASCII ones when the terminal cannot be
/// trusted with anything outside it.
class AnonymousSpinnerStatus extends Status {
  AnonymousSpinnerStatus({
    required super.stopwatch,
    required this.terminal,
    required this.write,
    super.onFinish,
    super.timeout,
  });

  static const List<String> _frames = <String>['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  static const List<String> _asciiFrames = <String>[r'-', r'\', r'|', r'/'];
  static const Duration _interval = Duration(milliseconds: 80);

  /// The terminal whose colours and character support decide how this spinner looks.
  final Terminal terminal;

  /// Where this status writes, so it reaches the user through the logger.
  final void Function(String message) write;

  Timer? _timer;
  int _ticks = 0;
  int _lastLength = 0;

  /// The number of frames drawn since this spinner started.
  int get ticks => _ticks;

  List<String> get _spinner => terminal.supportsEmoji ? _frames : _asciiFrames;

  @override
  void start() {
    super.start();
    _startSpinning();
  }

  @override
  void stop() {
    _stopSpinning();
    super.stop();
  }

  @override
  void cancel() {
    _stopSpinning();
    super.cancel();
  }

  @override
  void pause() {
    _clear();
    _timer?.cancel();
  }

  @override
  void resume() => _startSpinning();

  void _startSpinning() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (Timer _) => _tick());
    _tick();
  }

  void _stopSpinning() {
    _timer?.cancel();
    _timer = null;
    _clear();
  }

  void _tick() {
    final String frame = _spinner[_ticks % _spinner.length];
    _ticks += 1;
    _clear();
    final String rendered = terminal.color(frame, TerminalColor.cyan);
    _lastLength = 1;
    write(rendered);
  }

  void _clear() {
    if (_lastLength == 0) return;
    write('\b' * _lastLength);
    write(' ' * _lastLength);
    write('\b' * _lastLength);
    _lastLength = 0;
  }
}

/// An [AnonymousSpinnerStatus] preceded by a message and closed by a success mark.
class SpinnerStatus extends AnonymousSpinnerStatus {
  SpinnerStatus({
    required this.message,
    required super.stopwatch,
    required super.terminal,
    required super.write,
    super.onFinish,
    super.timeout,
  });

  /// The text naming the work being done.
  final String message;

  bool _printed = false;

  @override
  void start() {
    _print();
    super.start();
  }

  @override
  void stop() {
    super.stop();
    write('${terminal.successMark} $elapsed\n');
  }

  @override
  void cancel() {
    super.cancel();
    write('\n');
  }

  void _print() {
    if (_printed) return;
    _printed = true;
    write('${message.padRight(_kMessageColumns)} ');
  }
}

const int _kMessageColumns = 52;
