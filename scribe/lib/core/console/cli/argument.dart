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

import 'exception.dart';

class Flag {
  const Flag(this.name, {this.abbr, this.help, this.defaultsTo = false, this.negatable = true})
    : assert(name != '', 'Flag name must not be empty'),
      assert(abbr == null || abbr.length == 1, 'Flag abbr must be a single character');

  final String name;
  final String? abbr;
  final String? help;
  final bool defaultsTo;
  final bool negatable;

  String get invocation => abbr == null ? '    --$name' : '-$abbr, --$name';
}

abstract class Option<T> {
  const Option(this.name, {this.abbr, this.help, this.valueHelp = 'value', this.defaultsTo})
    : assert(name != '', 'Option name must not be empty'),
      assert(abbr == null || abbr.length == 1, 'Option abbr must be a single character');

  final String name;
  final String? abbr;
  final String? help;
  final String valueHelp;
  final T? defaultsTo;

  List<String>? get allowed => null;

  T parse(String raw);

  Never invalid(String expectation, String raw) => throw CliUsageError('--$name expects $expectation, got "$raw".');

  String get invocation => '${abbr == null ? '    ' : '-$abbr, '}--$name <$valueHelp>';

  String? get defaultLabel => defaultsTo == null ? null : '$defaultsTo';
}

class TextOption extends Option<String> {
  const TextOption(super.name, {super.abbr, super.help, super.valueHelp, super.defaultsTo, this.values});

  final List<String>? values;

  @override
  List<String>? get allowed => values;

  @override
  String parse(String raw) => raw;
}

class IntOption extends Option<int> {
  const IntOption(
    super.name, {
    super.abbr,
    super.help,
    super.valueHelp = 'number',
    super.defaultsTo,
    this.min,
    this.max,
  });

  final int? min;
  final int? max;

  @override
  int parse(String raw) {
    final int? value = int.tryParse(raw);
    if (value == null) invalid('a whole number', raw);

    final int? floor = min;
    if (floor != null && value < floor) invalid('a number greater than or equal to $floor', raw);

    final int? ceiling = max;
    if (ceiling != null && value > ceiling) invalid('a number lower than or equal to $ceiling', raw);

    return value;
  }
}

class EnumOption<T extends Enum> extends Option<T> {
  const EnumOption(super.name, this.options, {super.abbr, super.help, super.valueHelp, super.defaultsTo});

  final List<T> options;

  @override
  List<String> get allowed => <String>[for (final T option in options) option.name];

  @override
  T parse(String raw) {
    for (final T option in options) {
      if (option.name == raw) return option;
    }
    invalid('one of ${allowed.join(', ')}', raw);
  }

  @override
  String? get defaultLabel => defaultsTo?.name;
}

class Positional {
  const Positional(this.name, {this.help, this.isRequired = true, this.isRest = false})
    : assert(name != '', 'Positional name must not be empty');

  final String name;
  final String? help;
  final bool isRequired;
  final bool isRest;

  String get invocation => isRest ? '[$name...]' : (isRequired ? '<$name>' : '[$name]');
}

class Arguments {
  const Arguments({
    this.flags = const <String, bool>{},
    this.values = const <String, Object?>{},
    this.options = const <String, String>{},
    this.positionals = const <String, String>{},
    this.rest = const <String>[],
    this.wantsHelp = false,
    this.wantsVersion = false,
  });

  final Map<String, bool> flags;
  final Map<String, Object?> values;
  final Map<String, String> options;
  final Map<String, String> positionals;
  final List<String> rest;
  final bool wantsHelp;
  final bool wantsVersion;

  bool get isEmpty => rest.isEmpty && options.isEmpty && !flags.values.any((bool value) => value);

  bool flag(String name) => flags[name] ?? false;

  bool has(Flag flag) => flags[flag.name] ?? flag.defaultsTo;

  String? option(String name) => options[name];

  T? get<T>(Option<T> option) => values[option.name] as T? ?? option.defaultsTo;

  T require<T>(Option<T> option) => get<T>(option) ?? (throw CliUsageError('Option --${option.name} is required.'));

  String? positional(Positional positional) => positionals[positional.name];

  String requirePositional(Positional positional) =>
      positionals[positional.name] ?? (throw CliUsageError('Argument <${positional.name}> is required.'));

  String? get first => rest.isEmpty ? null : rest.first;
}
