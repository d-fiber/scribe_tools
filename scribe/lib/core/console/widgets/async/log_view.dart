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
import '../text/text.dart';

class LogView extends StatefulWidget {
  const LogView({required this.stream, this.height = 10, this.color, this.initial = const <String>[], super.key})
    : assert(height > 0, 'LogView height must be greater than zero');

  final Stream<String> stream;
  final int height;
  final Color? color;
  final List<String> initial;

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final List<String> _lines = <String>[...widget.initial];
  StreamSubscription<String>? _subscription;

  @override
  void initState() => _subscription = widget.stream.listen(_append, onError: _appendError);

  @override
  void didUpdateWidget(LogView previous) {
    if (identical(previous.stream, widget.stream)) return;

    _subscription?.cancel();
    _subscription = widget.stream.listen(_append, onError: _appendError);
  }

  @override
  void dispose() => _subscription?.cancel();

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final Color color = widget.color ?? theme.colors.text.secondary;
    final int start = _lines.length - widget.height < 0 ? 0 : _lines.length - widget.height;

    return Column(
      children: <Widget>[for (int index = start; index < _lines.length; index++) Text(_lines[index], color: color)],
    );
  }

  void _append(String line) {
    if (!mounted) return;

    setState(() {
      _lines.addAll(line.split('\n'));
      final int excess = _lines.length - widget.height * 4;
      if (excess > 0) _lines.removeRange(0, excess);
    });
  }

  void _appendError(Object error) => _append('$error');
}
