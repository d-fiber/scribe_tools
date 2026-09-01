// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/shell.dart';

/// Prints a shell completion script for this tool, read off the commands it holds.
///
/// The tree it walks is `runner.commands` itself, so a command added to
/// `bin/scribe.dart` completes from the day it is added, with nothing to keep
/// in step by hand.
///
/// It only completes command words and long flag names, never a flag's value:
/// `--sdk` completes, the SDK it takes does not. That is the one simplification
/// that keeps a single generator honest for three shells instead of growing a
/// second, richer one for each.
class CompletionCommand extends ScribeCommand {
  @override
  String get name => 'completion';

  @override
  String get description => 'Print a shell completion script for this tool.';

  @override
  String get invocation => 'scribe completion [bash|zsh|fish]';

  @override
  bool get requiresProject => false;

  /// This prints a script, and a script runs on a machine that has not
  /// installed anything yet.
  @override
  bool get checksMachine => false;

  /// The output is meant to be sourced or redirected to a file, so nothing
  /// beyond the script itself may reach standard output.
  @override
  bool get checksVersion => false;

  @override
  Future<ScribeCommandResult> runCommand() async {
    final ShellKind kind = _shellOf(optionalPositional('shell'));

    final Map<String, _CommandNode> tree = _tree(runner!.commands);
    final List<String> globalFlags = <String>[
      for (final Option option in runner!.argParser.options.values)
        if (!option.hide) '--${option.name}',
    ]..sort();
    final List<_Path> paths = _paths(tree, globalFlags);

    final String script = switch (kind) {
      ShellKind.fish => _fishScript(paths),
      ShellKind.zsh => _zshScript(paths),
      _ => _bashScript(paths),
    };

    globals.logger.printStatus(script, newline: false);

    return const ScribeCommandResult.success();
  }

  ShellKind _shellOf(String? requested) {
    if (requested == null) {
      final ShellKind detected = Shell.detect(platform: globals.platform, fileSystem: globals.fs).kind;
      if (detected == ShellKind.bash || detected == ShellKind.zsh || detected == ShellKind.fish) return detected;

      throwUsageError(
        'The shell could not be told apart from bash, zsh and fish. Name one: scribe completion bash.',
        command: invocationName,
      );
    }

    return switch (requested) {
      'bash' => ShellKind.bash,
      'zsh' => ShellKind.zsh,
      'fish' => ShellKind.fish,
      _ => throwUsageError('Unknown shell "$requested". Expected one of: bash, zsh, fish.', command: invocationName),
    };
  }
}

/// One command's own flags, and the commands that sit under it.
class _CommandNode {
  const _CommandNode({required this.flags, required this.children});

  final List<String> flags;
  final Map<String, _CommandNode> children;
}

/// [commands], read into a tree keyed the way `scribe <name>` types it.
///
/// A hidden command is left out: `package:args` registers `help` on every
/// runner, and completing it would offer a word nothing documents.
Map<String, _CommandNode> _tree(Map<String, Command<void>> commands) => <String, _CommandNode>{
  for (final MapEntry<String, Command<void>> entry in commands.entries)
    if (!entry.value.hidden)
      entry.key: _CommandNode(
        flags: <String>[
          for (final Option option in entry.value.argParser.options.values)
            if (!option.hide) '--${option.name}',
        ]..sort(),
        children: _tree(entry.value.subcommands),
      ),
};

/// One point a completion may be asked for: the words typed to reach it, and
/// what answers at that point, subcommands and flags together.
class _Path {
  const _Path({required this.words, required this.subcommands, required this.flags});

  /// The command path this answers for, `[]` for the bare `scribe`.
  final List<String> words;

  /// The names of the commands that sit directly under [words].
  final List<String> subcommands;

  /// The flags this point answers, this command's own and every global one.
  final List<String> flags;
}

/// [tree], flattened into one [_Path] per node, root included.
List<_Path> _paths(Map<String, _CommandNode> tree, List<String> globalFlags) {
  final List<_Path> paths = <_Path>[
    _Path(words: const <String>[], subcommands: tree.keys.toList()..sort(), flags: globalFlags),
  ];
  _walk(tree, globalFlags, const <String>[], paths);
  return paths;
}

void _walk(Map<String, _CommandNode> tree, List<String> globalFlags, List<String> prefix, List<_Path> out) {
  for (final MapEntry<String, _CommandNode> entry in tree.entries) {
    final List<String> here = <String>[...prefix, entry.key];
    final List<String> flags = <String>{...entry.value.flags, ...globalFlags}.toList()..sort();

    out.add(_Path(words: here, subcommands: entry.value.children.keys.toList()..sort(), flags: flags));
    _walk(entry.value.children, globalFlags, here, out);
  }
}

String _bashScript(List<_Path> paths) => '#!/usr/bin/env bash\n${_bashFunction(paths)}';

String _zshScript(List<_Path> paths) =>
    '#!/usr/bin/env zsh\nautoload -U +X bashcompinit && bashcompinit\n${_bashFunction(paths)}';

/// The completion function bash and zsh share, zsh reaching it through `bashcompinit`.
///
/// One generator instead of two: a native zsh completion answers the same
/// question, command word by command word, and a second implementation would
/// only be a second place for the two to drift apart.
String _bashFunction(List<_Path> paths) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('_scribe_complete() {')
    ..writeln(r'  local cur words path i')
    ..writeln(r'  cur="${COMP_WORDS[COMP_CWORD]}"')
    ..writeln(r'  words=("${COMP_WORDS[@]:1:COMP_CWORD-1}")')
    ..writeln('  path=""')
    ..writeln(r'  for i in "${words[@]}"; do')
    ..writeln(r'    case "$i" in')
    ..writeln('      -*) ;;')
    ..writeln(r'      *) path="${path:+$path }$i" ;;')
    ..writeln('    esac')
    ..writeln('  done')
    ..writeln(r'  case "$path" in');

  for (final _Path path in paths) {
    final String key = path.words.join(' ');
    final String words = <String>[...path.subcommands, ...path.flags].join(' ');
    buffer.writeln('    "$key") COMPREPLY=( \$(compgen -W "$words" -- "\$cur") ) ;;');
  }

  buffer
    ..writeln('    *) COMPREPLY=() ;;')
    ..writeln('  esac')
    ..writeln('}')
    ..writeln('complete -F _scribe_complete scribe');

  return buffer.toString();
}

/// Fish reads by condition rather than by position, so each [_Path] becomes
/// one `-n` guard per word instead of one `case` branch.
String _fishScript(List<_Path> paths) {
  final StringBuffer buffer = StringBuffer()..writeln('complete -c scribe -f');

  for (final _Path path in paths) {
    final String condition = _fishCondition(path.words);

    if (path.subcommands.isNotEmpty) {
      buffer.writeln("complete -c scribe -n '$condition' -a '${path.subcommands.join(' ')}'");
    }

    for (final String flag in path.flags) {
      buffer.writeln("complete -c scribe -n '$condition' -l ${flag.substring(2)}");
    }
  }

  return buffer.toString();
}

String _fishCondition(List<String> words) => words.isEmpty
    ? '__fish_use_subcommand'
    : words.map((String word) => '__fish_seen_subcommand_from $word').join('; and ');
