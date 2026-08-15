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

import '../../framework/framework.dart';
import '../layout/row.dart';
import '../text/text.dart';

class Spinner extends StatefulWidget {
  const Spinner({this.label, this.color, this.frames, this.interval, super.key});

  final String? label;
  final Color? color;
  final List<String>? frames;
  final Duration? interval;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> {
  Ticker? _ticker;
  int _tick = 0;

  @override
  void didChangeDependencies() {
    if (_ticker != null) return;

    final ProgressStyle style = ConsoleTheme.of(context).styles.progress;
    _ticker = Ticker(_advance, interval: widget.interval ?? style.interval)..start();
  }

  @override
  void dispose() => _ticker?.stop();

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final List<String> frames = widget.frames ?? theme.styles.progress.spinner;
    final Color color = widget.color ?? theme.colors.action.primary;
    final String label = widget.label ?? '';

    return Row(
      children: <Widget>[
        Text(frames[_tick % frames.length], color: color),
        if (label.isNotEmpty) ...<Widget>[const Text(' '), Text(label, color: theme.colors.text.primary)],
      ],
    );
  }

  void _advance(int tick) {
    if (!mounted) return;
    setState(() => _tick = tick);
  }
}
