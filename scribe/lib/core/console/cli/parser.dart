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

import 'argument.dart';
import 'command.dart';
import 'exception.dart';

class Invocation {
  const Invocation({
    required this.command,
    required this.path,
    required this.arguments,
    this.chain = const <Command>[],
  });

  final Command? command;
  final List<Command> chain;
  final List<String> path;
  final Arguments arguments;

  bool get wantsHelp => arguments.wantsHelp;

  bool get wantsVersion => arguments.wantsVersion;
}

class Grammar {
  const Grammar({
    this.flags = const <Flag>[],
    this.options = const <Option<Object?>>[],
    this.positionals = const <Positional>[],
  });

  final List<Flag> flags;
  final List<Option<Object?>> options;
  final List<Positional> positionals;

  Grammar merge(Grammar other) => Grammar(
    flags: <Flag>[...flags, ...other.flags],
    options: <Option<Object?>>[...options, ...other.options],
    positionals: <Positional>[...positionals, ...other.positionals],
  );

  static Grammar of(Command command) =>
      Grammar(flags: command.flags, options: command.options, positionals: command.positionals);
}

Invocation resolveInvocation(List<Command> roots, List<String> input, {Grammar globals = const Grammar()}) {
  final List<String> tokens = input.first == 'help' ? <String>[...input.skip(1), '--help'] : input;

  final List<String> path = <String>[];
  final List<Command> chain = <Command>[];
  List<Command> available = roots;
  Command? command;
  int index = 0;

  while (index < tokens.length) {
    final String token = tokens[index];
    if (token.startsWith('-')) break;

    final Command? match = _match(available, token);
    if (match == null) {
      if (command == null || command.isGroup) {
        throw CliUsageError('Unknown command "$token".', path: path);
      }
      break;
    }

    command = match;
    chain.add(match);
    path.add(match.name);
    available = match.commands;
    index++;
  }

  final List<String> rest = tokens.sublist(index);
  if (command == null) {
    return Invocation(command: null, path: path, arguments: parseArguments(globals, rest, path));
  }

  return Invocation(
    command: command,
    chain: chain,
    path: path,
    arguments: parseArguments(globals.merge(Grammar.of(command)), rest, path),
  );
}

Command? _match(List<Command> commands, String token) {
  for (final Command command in commands) {
    if (command.answersTo(token)) return command;
  }
  return null;
}

Arguments parseArguments(Grammar grammar, List<String> tokens, List<String> path) {
  final Map<String, bool> flags = <String, bool>{for (final Flag flag in grammar.flags) flag.name: flag.defaultsTo};
  final Map<String, String> raw = <String, String>{};
  final Map<String, Object?> values = <String, Object?>{};
  final List<String> rest = <String>[];

  bool wantsHelp = false;
  bool wantsVersion = false;
  int index = 0;

  while (index < tokens.length) {
    final String token = tokens[index];
    index++;

    if (token == '--') {
      rest.addAll(tokens.sublist(index));
      break;
    }
    if (token == '--help' || token == '-h') {
      wantsHelp = true;
      continue;
    }
    if (token == '--version') {
      wantsVersion = true;
      continue;
    }
    if (token.length < 2 || !token.startsWith('-')) {
      rest.add(token);
      continue;
    }

    final bool long = token.startsWith('--');
    final String body = long ? token.substring(2) : token.substring(1);
    final int equals = body.indexOf('=');
    final String label = equals < 0 ? body : body.substring(0, equals);
    final String? inlineValue = equals < 0 ? null : body.substring(equals + 1);

    final Option<Object?>? option = _findOption(grammar, label, long: long);
    if (option != null) {
      final String? value = inlineValue ?? (index < tokens.length ? tokens[index] : null);
      if (value == null) throw CliUsageError('Option --${option.name} needs a value.', path: path);
      if (inlineValue == null) index++;

      final List<String>? allowed = option.allowed;
      if (allowed != null && !allowed.contains(value)) {
        throw CliUsageError('--${option.name} only accepts ${allowed.join(', ')}.', path: path);
      }

      raw[option.name] = value;
      values[option.name] = _parse(option, value, path);
      continue;
    }

    final Flag? flag = _findFlag(grammar, label, long: long);
    if (flag != null) {
      if (inlineValue != null) throw CliUsageError('Flag --${flag.name} does not take a value.', path: path);
      flags[flag.name] = true;
      continue;
    }

    if (long && label.startsWith('no-')) {
      final Flag? negated = _findFlag(grammar, label.substring(3), long: true);
      if (negated != null && negated.negatable) {
        flags[negated.name] = false;
        continue;
      }
    }

    throw CliUsageError('Unknown option "$token".', path: path);
  }

  return Arguments(
    flags: flags,
    values: values,
    options: raw,
    positionals: _bindPositionals(grammar.positionals, rest, path, skipValidation: wantsHelp || wantsVersion),
    rest: rest,
    wantsHelp: wantsHelp,
    wantsVersion: wantsVersion,
  );
}

Object? _parse(Option<Object?> option, String value, List<String> path) {
  try {
    return option.parse(value);
  } on CliUsageError catch (error) {
    throw CliUsageError(error.message, path: path);
  }
}

Map<String, String> _bindPositionals(
  List<Positional> declared,
  List<String> rest,
  List<String> path, {
  required bool skipValidation,
}) {
  if (declared.isEmpty) return const <String, String>{};

  final Map<String, String> bound = <String, String>{};
  int cursor = 0;

  for (final Positional positional in declared) {
    if (positional.isRest) {
      bound[positional.name] = rest.sublist(cursor.clamp(0, rest.length)).join(' ');
      cursor = rest.length;
      continue;
    }

    if (cursor < rest.length) {
      bound[positional.name] = rest[cursor];
      cursor++;
      continue;
    }

    if (positional.isRequired && !skipValidation) {
      throw CliUsageError('Missing required argument <${positional.name}>.', path: path);
    }
  }

  if (cursor < rest.length && !skipValidation && !declared.any((Positional entry) => entry.isRest)) {
    throw CliUsageError('Unexpected argument "${rest[cursor]}".', path: path);
  }

  return bound;
}

Option<Object?>? _findOption(Grammar grammar, String label, {required bool long}) {
  for (final Option<Object?> option in grammar.options) {
    if (long ? option.name == label : option.abbr == label) return option;
  }
  return null;
}

Flag? _findFlag(Grammar grammar, String label, {required bool long}) {
  for (final Flag flag in grammar.flags) {
    if (long ? flag.name == label : flag.abbr == label) return flag;
  }
  return null;
}
