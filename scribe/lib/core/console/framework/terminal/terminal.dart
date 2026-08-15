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

const String _escape = '\x1B';

final RegExp _cursorReply = RegExp(r'\[(\d+);(\d+)R');

int? cursorRowFromReply(String reply) {
  final RegExpMatch? match = _cursorReply.firstMatch(reply);
  return match == null ? null : int.tryParse(match.group(1)!);
}

const Map<int, ControlCharacter> _escapeLetters = <int, ControlCharacter>{
  0x41: ControlCharacter.arrowUp,
  0x42: ControlCharacter.arrowDown,
  0x43: ControlCharacter.arrowRight,
  0x44: ControlCharacter.arrowLeft,
  0x46: ControlCharacter.end,
  0x48: ControlCharacter.home,
};

const Map<int, ControlCharacter> _escapeDigits = <int, ControlCharacter>{
  0x31: ControlCharacter.home,
  0x33: ControlCharacter.delete,
  0x34: ControlCharacter.end,
  0x35: ControlCharacter.pageUp,
  0x36: ControlCharacter.pageDown,
  0x37: ControlCharacter.home,
  0x38: ControlCharacter.end,
};

class Terminal implements ConsoleSurface {
  Terminal({Stdin? input, Stdout? output}) : _input = input ?? stdin, _output = output ?? stdout;

  final Stdin _input;
  final Stdout _output;

  final List<ConsoleEvent> _pending = <ConsoleEvent>[];
  final List<int> _buffer = <int>[];
  final List<int> _report = <int>[];

  StreamSubscription<List<int>>? _subscription;
  StreamSubscription<ProcessSignal>? _interrupts;
  StreamSubscription<ProcessSignal>? _resizes;
  Completer<ConsoleEvent?>? _waiting;
  Completer<String>? _reporting;
  bool Function(String reply)? _completed;
  int? _originRow;
  List<String> _previous = const <String>[];
  int _drawn = 0;
  bool _echo = true;
  bool _line = true;
  bool _raw = false;
  bool _flow = false;
  bool _fullscreen = false;
  bool _mouse = false;

  void Function()? onResize;
  void Function(Brightness brightness)? onBrightness;

  @override
  bool get fullscreen => _fullscreen;

  int get rows => _output.hasTerminal ? _output.terminalLines : 0;

  @override
  int? get viewportHeight {
    final int total = rows;
    if (total <= 0) return null;
    if (_fullscreen) return total;

    final int? origin = _originRow;
    if (origin == null) return null;

    final int available = total - origin + 1;
    return available < 1 ? 1 : available;
  }

  @override
  int get columns => _output.hasTerminal ? _output.terminalColumns : 0;

  @override
  int get originRow => _fullscreen ? 1 : _originRow ?? 1;

  @override
  bool get mouse => _mouse;

  @override
  set mouse(bool value) {
    if (_mouse == value || !_output.hasTerminal) return;
    _mouse = value;
    _write(value ? '$_escape[?1000h$_escape[?1006h' : '$_escape[?1006l$_escape[?1000l');
  }

  @override
  set fullscreen(bool value) {
    if (_fullscreen == value) return;
    if (value) erase();
    _fullscreen = value;
    _previous = const <String>[];
    _drawn = 0;
    _write(value ? '$_escape[?1049h$_escape[?1007h$_escape[H' : '$_escape[?1007l$_escape[?1049l');
  }

  @override
  void setTitle(String title) => _write('$_escape]0;$title\x07');

  @override
  void start() {
    _raw = _enterRawMode();
    if (_raw) {
      _interrupts = ProcessSignal.sigint.watch().listen(_abort);
      if (!Platform.isWindows) _resizes = ProcessSignal.sigwinch.watch().listen(_resized);
    }
    _write(_raw ? '$_escape[?25l$_escape[?2031h' : '$_escape[?25l');
    _subscription = _input.listen(_receive, onDone: interrupt);
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _interrupts?.cancel();
    _interrupts = null;
    _resizes?.cancel();
    _resizes = null;
    mouse = false;
    fullscreen = false;
    erase();
    _write(_raw ? '$_escape[?2031l$_escape[?25h' : '$_escape[?25h');
    _leaveRawMode();
  }

  bool _enterRawMode() {
    if (!_input.hasTerminal) return false;

    try {
      _echo = _input.echoMode;
      _line = _input.lineMode;
      _input.lineMode = false;
      _input.echoMode = false;
    } on StdinException {
      return false;
    }

    _flow = _flowControl;
    _stty('-ixon');
    return true;
  }

  void _leaveRawMode() {
    if (!_raw) return;
    _raw = false;

    if (_flow) _stty('ixon');
    _flow = false;

    try {
      _input.echoMode = _echo;
      _input.lineMode = _line;
    } on StdinException {
      return;
    }
  }

  bool get _flowControl {
    final String? settings = _stty('-a');
    return settings != null && !settings.contains('-ixon');
  }

  String? _stty(String mode) {
    if (Platform.isWindows) return null;

    try {
      final ProcessResult result = Process.runSync('/bin/sh', <String>['-c', 'stty $mode < /dev/tty 2>/dev/null']);
      return result.exitCode == 0 ? '${result.stdout}' : null;
    } on ProcessException {
      return null;
    }
  }

  @override
  Future<Brightness?> queryBrightness({Duration timeout = const Duration(milliseconds: 150)}) async {
    if (!_raw || !_output.hasTerminal) return null;

    final String? reply = await _request('$_escape]11;?\x07', _endsReport, timeout);
    return reply == null ? null : brightnessFromReply(reply);
  }

  @override
  Future<void> locate({Duration timeout = const Duration(milliseconds: 150)}) async {
    if (!_raw || !_output.hasTerminal) return;

    final String? reply = await _request('$_escape[6n', _endsPosition, timeout);
    final int? row = reply == null ? null : cursorRowFromReply(reply);
    if (row != null) _originRow = row - _drawn;
  }

  @override
  Future<void> relocate() async {
    if (_originRow == null) return;
    await locate();
  }

  bool _endsReport(String reply) => reply.contains('\x07') || reply.contains('$_escape\\');

  bool _endsPosition(String reply) => reply.contains('R');

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

  @override
  void draw(Frame frame) {
    final List<String> visible = _fit(frame.lines);

    if (_fullscreen) {
      _drawScreen(visible);
      return;
    }

    final List<String> lines = visible;
    final StringBuffer out = StringBuffer();
    if (_drawn > 0) out.write('$_escape[${_drawn}A');

    final int rows = lines.length > _drawn ? lines.length : _drawn;
    for (int row = 0; row < rows; row++) {
      final String line = row < lines.length ? lines[row] : '';
      final bool unchanged = row < lines.length && row < _previous.length && _previous[row] == line;
      out.write(unchanged ? '\n' : '\r$_escape[2K$line\n');
    }
    if (rows > lines.length) out.write('$_escape[${rows - lines.length}A');

    _write(out.toString());
    _previous = lines;
    _drawn = lines.length;
  }

  void _drawScreen(List<String> lines) {
    final int height = rows > 0 ? rows : lines.length;
    final List<String> painted = <String>[for (int row = 0; row < height; row++) row < lines.length ? lines[row] : ''];

    final StringBuffer out = StringBuffer();
    for (int row = 0; row < height; row++) {
      if (row < _previous.length && _previous[row] == painted[row]) continue;
      out.write('$_escape[${row + 1};1H$_escape[2K${painted[row]}');
    }

    _write(out.toString());
    _previous = painted;
  }

  void _resized(ProcessSignal signal) {
    _previous = const <String>[];
    onResize?.call();
  }

  List<String> _fit(List<String> lines) {
    final int? limit = viewportHeight;
    if (limit == null || lines.length <= limit) return lines;
    if (_fullscreen) return lines.sublist(0, limit);

    _scrollUp(lines.length - limit);

    final int? available = viewportHeight;
    return available == null || lines.length <= available ? lines : lines.sublist(0, available);
  }

  void _scrollUp(int delta) {
    final int? origin = _originRow;
    final int total = rows;
    if (origin == null || total <= 0) return;

    final int shift = origin - 1 < delta ? origin - 1 : delta;
    if (shift <= 0) return;

    final int moved = origin - shift;
    _write('$_escape[$total;1H${'\n' * shift}$_escape[$moved;1H');
    _originRow = moved;
    _previous = const <String>[];
    _drawn = 0;
  }

  @override
  void erase() {
    if (_fullscreen) {
      _write('$_escape[2J$_escape[H');
      _previous = const <String>[];
      return;
    }
    if (_drawn == 0) return;
    final StringBuffer out = StringBuffer('$_escape[${_drawn}A');
    for (int row = 0; row < _drawn; row++) {
      out.write('\r$_escape[2K\n');
    }
    out.write('$_escape[${_drawn}A');
    _write(out.toString());
    _previous = const <String>[];
    _drawn = 0;
  }

  void _abort(ProcessSignal signal) {
    stop();
    exit(130);
  }

  void _write(String text) => _output.write(text);

  Future<String?> _request(String query, bool Function(String reply) completed, Duration timeout) async {
    final Completer<String> reporting = Completer<String>();
    _reporting = reporting;
    _completed = completed;
    _report.clear();
    _write(query);

    try {
      return await reporting.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      _reporting = null;
      _completed = null;
      _report.clear();
    }
  }

  void _receive(List<int> bytes) {
    final Completer<String>? reporting = _reporting;
    if (reporting != null) {
      _report.addAll(bytes);
      final String reply = String.fromCharCodes(_report);
      if (_completed!(reply)) {
        _reporting = null;
        reporting.complete(reply);
      }
      return;
    }

    _buffer.addAll(bytes);
    _pending.addAll(_decode(_buffer));

    final Completer<ConsoleEvent?>? waiting = _waiting;
    if (waiting == null || _pending.isEmpty) return;
    _waiting = null;
    waiting.complete(_pending.removeAt(0));
  }

  List<ConsoleEvent> _decode(List<int> buffer) {
    final List<ConsoleEvent> keys = <ConsoleEvent>[];
    while (buffer.isNotEmpty) {
      final int code = buffer.removeAt(0);
      if (code == 0x1b) {
        final ConsoleEvent? event = _decodeEscape(buffer);
        if (event != null) keys.add(event);
        continue;
      }
      if (code == 0x7f) {
        keys.add(KeyEvent(Key.control(ControlCharacter.backspace)));
        continue;
      }
      if (code == 0x0a) {
        keys.add(KeyEvent(Key.control(ControlCharacter.enter)));
        continue;
      }
      if (code >= 0x01 && code <= 0x1a) {
        keys.add(KeyEvent(Key.control(ControlCharacter.values[code])));
        continue;
      }
      if (code < 0x20) continue;
      final String char = _decodeChar(code, buffer);
      if (char.length == 1) keys.add(KeyEvent(Key.printable(char)));
    }
    return keys;
  }

  ConsoleEvent? _decodeEscape(List<int> buffer) {
    if (buffer.isEmpty) return KeyEvent(Key.control(ControlCharacter.escape));
    if (buffer.first != 0x5b && buffer.first != 0x4f) return _decodeAlt(buffer);

    buffer.removeAt(0);
    if (buffer.isEmpty) return KeyEvent(Key.control(ControlCharacter.escape));
    if (buffer.first == 0x3c) {
      buffer.removeAt(0);
      return _decodeMouse(buffer);
    }
    if (buffer.first == 0x3f) {
      buffer.removeAt(0);
      return _decodeReport(buffer);
    }

    final int code = buffer.removeAt(0);
    if (code == 0x5a) return KeyEvent(Key.control(ControlCharacter.tab), shift: true);

    final ControlCharacter? letter = _escapeLetters[code];
    if (letter != null) return KeyEvent(Key.control(letter));
    if (buffer.isNotEmpty && buffer.first == 0x7e) buffer.removeAt(0);

    return KeyEvent(Key.control(_escapeDigits[code] ?? ControlCharacter.unknown));
  }

  ConsoleEvent _decodeAlt(List<int> buffer) {
    final int code = buffer.first;
    if (code == 0x7f) {
      buffer.removeAt(0);
      return KeyEvent(Key.control(ControlCharacter.backspace), alt: true);
    }
    if (code < 0x20) return KeyEvent(Key.control(ControlCharacter.escape));

    buffer.removeAt(0);
    final String char = _decodeChar(code, buffer);
    return char.length == 1 ? KeyEvent(Key.printable(char), alt: true) : KeyEvent(Key.control(ControlCharacter.escape));
  }

  ConsoleEvent? _decodeReport(List<int> buffer) {
    final StringBuffer report = StringBuffer();
    while (buffer.isNotEmpty) {
      final int code = buffer.removeAt(0);
      if (code < 0x40 || code > 0x7e) {
        report.writeCharCode(code);
        continue;
      }

      if (code == 0x6e) _reportBrightness(report.toString());
      return null;
    }
    return null;
  }

  void _reportBrightness(String report) {
    final Brightness? detected = brightnessFromNotification(report);
    if (detected != null) onBrightness?.call(detected);
  }

  ConsoleEvent? _decodeMouse(List<int> buffer) {
    final StringBuffer report = StringBuffer();
    while (buffer.isNotEmpty) {
      final int code = buffer.removeAt(0);
      if (code == 0x4d || code == 0x6d) return mouseFromReport(report.toString(), pressed: code == 0x4d);
      report.writeCharCode(code);
    }
    return null;
  }

  String _decodeChar(int code, List<int> buffer) {
    final List<int> bytes = <int>[code];
    while (buffer.isNotEmpty && buffer.first >= 0x80 && buffer.first < 0xc0) {
      bytes.add(buffer.removeAt(0));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
