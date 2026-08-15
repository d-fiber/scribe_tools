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

import '../framework/framework.dart';
import '../widgets/layout/column.dart';
import '../widgets/list/tile.dart';
import '../widgets/text/text.dart';
import 'app.dart';
import 'argument.dart';
import 'command.dart';

class Usage extends StatelessWidget {
  const Usage({required this.app, this.command, this.path = const <String>[], this.error, super.key});

  final Cli app;
  final Command? command;
  final List<String> path;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ConsoleTheme theme = ConsoleTheme.of(context);
    final Command? current = command;
    final List<Command> commands = current == null ? app.visibleCommands : current.visibleCommands;
    final List<Positional> positionals = current?.positionals ?? const <Positional>[];
    final List<Flag> flags = current?.flags ?? const <Flag>[];
    final List<Option<Object?>> options = current?.options ?? const <Option<Object?>>[];
    final int width = _width(commands, positionals, flags, options);

    return Column(
      children: <Widget>[
        if (error case final String message) ...<Widget>[
          Text(message, color: theme.colors.feedback.error, style: TextStyle.bold),
          const Text(''),
        ],
        Text(current?.description ?? app.description, color: theme.colors.text.primary),
        const Text(''),
        Text('Usage', color: theme.colors.text.secondary, style: TextStyle.bold),
        Text('  ${_usageLine()}'),
        if (commands.isNotEmpty) ...<Widget>[
          const Text(''),
          Text('Commands', color: theme.colors.text.secondary, style: TextStyle.bold),
          for (final Command command in commands) _row(theme, command.name, command.description, width),
        ],
        if (positionals.isNotEmpty) ...<Widget>[
          const Text(''),
          Text('Arguments', color: theme.colors.text.secondary, style: TextStyle.bold),
          for (final Positional positional in positionals)
            _row(theme, positional.invocation, positional.help ?? '', width),
        ],
        const Text(''),
        Text('Options', color: theme.colors.text.secondary, style: TextStyle.bold),
        for (final Flag flag in flags) _row(theme, flag.invocation, flag.help ?? '', width),
        for (final Option<Object?> option in options) _row(theme, option.invocation, _help(option), width),
        _row(theme, helpFlag.invocation, helpFlag.help ?? '', width),
        if (app.globalFlags.isNotEmpty || app.globalOptions.isNotEmpty) ...<Widget>[
          const Text(''),
          Text('Global options', color: theme.colors.text.secondary, style: TextStyle.bold),
          for (final Flag flag in app.globalFlags) _row(theme, flag.invocation, flag.help ?? '', width),
          for (final Option<Object?> option in app.globalOptions) _row(theme, option.invocation, _help(option), width),
        ],
      ],
    );
  }

  String _help(Option<Object?> option) {
    final String help = option.help ?? '';
    final String? fallback = option.defaultLabel;
    final List<String>? allowed = option.allowed;

    return <String>[
      if (help.isNotEmpty) help,
      if (allowed != null) '[${allowed.join(', ')}]',
      if (fallback != null) '(defaults to $fallback)',
    ].join(' ');
  }

  int _width(List<Command> commands, List<Positional> positionals, List<Flag> flags, List<Option<Object?>> options) {
    final List<String> entries = <String>[
      for (final Command command in commands) command.name,
      for (final Positional positional in positionals) positional.invocation,
      for (final Flag flag in flags) flag.invocation,
      for (final Option<Object?> option in options) option.invocation,
      for (final Flag flag in app.globalFlags) flag.invocation,
      for (final Option<Object?> option in app.globalOptions) option.invocation,
      helpFlag.invocation,
    ];

    return entries.fold(0, (int widest, String entry) => entry.length > widest ? entry.length : widest) + 2;
  }

  Widget _row(ConsoleTheme theme, String label, String help, int width) => Tile(
    leading: const Text('  '),
    title: Text(label, color: theme.colors.action.primary),
    titleWidth: width,
    trailing: Text(help, color: theme.colors.text.secondary),
  );

  String _usageLine() {
    final String head = <String>[app.name, ...path].join(' ');
    final Command? current = command;
    if (current == null || current.isGroup) return '$head <command> [options]';
    if (current.usage case final String custom) return '$head $custom';

    final String arguments = <String>[
      for (final Positional positional in current.positionals) positional.invocation,
    ].join(' ');

    return arguments.isEmpty ? '$head [options]' : '$head $arguments [options]';
  }
}
