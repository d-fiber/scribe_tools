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

import '../widgets/text/text.dart';
import 'app.dart';
import 'argument.dart';
import 'command.dart';
import 'context.dart';

enum CompletionShell { fish, zsh, bash }

class CompletionCommand extends Command {
  const CompletionCommand();

  static const Positional shell = Positional('shell', help: 'fish, zsh or bash.');

  @override
  String get name => 'completion';

  @override
  String get description => 'Print a shell completion script for this CLI.';

  @override
  bool get hidden => true;

  @override
  List<Positional> get positionals => const <Positional>[shell];

  @override
  Future<void> run(Context cli) async {
    final String requested = cli.arguments.requirePositional(shell);
    final CompletionShell target = CompletionShell.values.firstWhere(
      (CompletionShell candidate) => candidate.name == requested,
      orElse: () => cli.usageError('Unknown shell "$requested". Use fish, zsh or bash.'),
    );

    cli.render(Text(renderCompletion(cli.app, target)));
  }
}

String renderCompletion(Cli app, CompletionShell shell) => switch (shell) {
  CompletionShell.fish => _fish(app),
  CompletionShell.zsh => _zsh(app),
  CompletionShell.bash => _bash(app),
};

List<String> _tokensOf(Command command, Cli app) => <String>[
  for (final Command child in command.visibleCommands) child.name,
  ..._switches(command.flags, command.options),
  ..._switches(app.globalFlags, app.globalOptions),
  '--help',
];

List<String> _switches(List<Flag> flags, List<Option<Object?>> options) => <String>[
  for (final Flag flag in flags) '--${flag.name}',
  for (final Option<Object?> option in options) '--${option.name}',
];

String _fish(Cli app) {
  final StringBuffer out = StringBuffer();

  void emit(List<String> path, List<Command> commands, List<String> switches) {
    final String seen = path.isEmpty
        ? '__fish_use_subcommand'
        : path.map((String step) => '__fish_seen_subcommand_from $step').join('; and ');

    for (final Command command in commands) {
      out.writeln("complete -c ${app.name} -f -n '$seen' -a '${command.name}' -d '${_escape(command.description)}'");
    }
    for (final String option in switches) {
      out.writeln("complete -c ${app.name} -f -n '$seen' -a '$option'");
    }
  }

  void walk(List<String> path, List<Command> commands, List<String> switches) {
    emit(path, commands, switches);
    for (final Command command in commands) {
      walk(<String>[...path, command.name], command.visibleCommands, _switches(command.flags, command.options));
    }
  }

  out.writeln('# ${app.name} completion for fish — save as ~/.config/fish/completions/${app.name}.fish');
  walk(const <String>[], app.visibleCommands, <String>[..._switches(app.globalFlags, app.globalOptions), '--help']);

  return out.toString().trimRight();
}

String _zsh(Cli app) {
  final StringBuffer out = StringBuffer()
    ..writeln('#compdef ${app.name}')
    ..writeln('# ${app.name} completion for zsh — save as _${app.name} on your \$fpath')
    ..writeln('_${app.name}() {')
    ..writeln('  local -a candidates')
    ..writeln('  case "\${words[2]}" in');

  for (final Command command in app.visibleCommands) {
    out
      ..writeln('    ${command.name})')
      ..writeln("      candidates=(${_tokensOf(command, app).map(_quote).join(' ')})")
      ..writeln('      ;;');
  }

  out
    ..writeln('    *)')
    ..writeln(
      "      candidates=(${<String>[for (final Command command in app.visibleCommands) command.name, ..._switches(app.globalFlags, app.globalOptions), '--help'].map(_quote).join(' ')})",
    )
    ..writeln('      ;;')
    ..writeln('  esac')
    ..writeln('  compadd -- \$candidates')
    ..writeln('}')
    ..writeln('compdef _${app.name} ${app.name}');

  return out.toString().trimRight();
}

String _bash(Cli app) {
  final StringBuffer out = StringBuffer()
    ..writeln('# ${app.name} completion for bash — source this file from your ~/.bashrc')
    ..writeln('_${app.name}() {')
    ..writeln('  local candidates')
    ..writeln('  case "\${COMP_WORDS[1]}" in');

  for (final Command command in app.visibleCommands) {
    out
      ..writeln('    ${command.name})')
      ..writeln('      candidates="${_tokensOf(command, app).join(' ')}"')
      ..writeln('      ;;');
  }

  out
    ..writeln('    *)')
    ..writeln(
      '      candidates="${<String>[for (final Command command in app.visibleCommands) command.name, ..._switches(app.globalFlags, app.globalOptions), '--help'].join(' ')}"',
    )
    ..writeln('      ;;')
    ..writeln('  esac')
    ..writeln('  COMPREPLY=(\$(compgen -W "\$candidates" -- "\${COMP_WORDS[COMP_CWORD]}"))')
    ..writeln('}')
    ..writeln('complete -F _${app.name} ${app.name}');

  return out.toString().trimRight();
}

String _quote(String value) => "'$value'";

String _escape(String value) => value.replaceAll("'", r"\'");
