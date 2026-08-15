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

import 'package:scribe/core/console/console.dart';
import 'package:scribe/core/console/testing/testing.dart';
import 'package:test/test.dart';

enum _Mode { fast, safe }

const TextOption _name = TextOption('name', abbr: 'n', help: 'Project name.');
const IntOption _count = IntOption('count', abbr: 'c', defaultsTo: 1, min: 1, max: 9);
const EnumOption<_Mode> _mode = EnumOption<_Mode>('mode', _Mode.values, defaultsTo: _Mode.safe);
const Positional _target = Positional('target', help: 'What to build.');
const Positional _extras = Positional('extras', isRequired: false, isRest: true);

class _Build extends Command {
  const _Build();

  @override
  String get name => 'build';

  @override
  List<String> get aliases => const <String>['b'];

  @override
  String get description => 'Build the project.';

  @override
  List<Flag> get flags => const <Flag>[Flag('watch', abbr: 'w')];

  @override
  List<Option<Object?>> get options => const <Option<Object?>>[_name, _count, _mode];

  @override
  List<Positional> get positionals => const <Positional>[_target, _extras];

  @override
  Future<void> run(Context cli) async {}
}

class _Group extends GroupCommand {
  const _Group();

  @override
  String get name => 'gen';

  @override
  String get description => 'Generate things.';

  @override
  List<Command> get commands => const <Command>[_Build()];
}

class _Hidden extends Command {
  const _Hidden();

  @override
  String get name => 'internal';

  @override
  String get description => 'Not listed.';

  @override
  bool get hidden => true;

  @override
  Future<void> run(Context cli) async {}
}

Cli _app() => Cli(
  name: 'demo',
  description: 'A demo CLI.',
  version: '2.1.0',
  globalFlags: const <Flag>[yesFlag],
  commands: const <Command>[_Build(), _Group(), _Hidden()],
);

Arguments _parse(List<String> input) {
  final Cli app = _app();
  return resolveInvocation(app.commands, input, globals: app.globals).arguments;
}

class _Traced extends Command {
  const _Traced();

  static final List<String> calls = <String>[];

  @override
  String get name => 'traced';

  @override
  String get description => 'Records the middleware order.';

  @override
  List<Middleware> get middlewares => <Middleware>[(Context cli) async => calls.add('leaf')];

  @override
  Future<void> run(Context cli) async => calls.add('run');
}

class _TracedGroup extends GroupCommand {
  const _TracedGroup();

  @override
  String get name => 'outer';

  @override
  String get description => 'Parent of traced.';

  @override
  List<Middleware> get middlewares => <Middleware>[(Context cli) async => _Traced.calls.add('group')];

  @override
  List<Command> get commands => const <Command>[_Traced()];
}

class _Boom extends Command {
  const _Boom();

  @override
  String get name => 'boom';

  @override
  String get description => 'Always fails.';

  @override
  Future<void> run(Context cli) async => cli.fail('exploded', exitCode: 7);
}

void main() {
  group('command resolution', () {
    test('resolves a command and its alias', () {
      final Cli app = _app();
      expect(resolveInvocation(app.commands, <String>['build', 'api']).path, <String>['build']);
      expect(resolveInvocation(app.commands, <String>['b', 'api']).path, <String>['build']);
    });

    test('walks into subcommands and records the chain', () {
      final Cli app = _app();
      final Invocation invocation = resolveInvocation(app.commands, <String>['gen', 'build', 'api']);

      expect(invocation.path, <String>['gen', 'build']);
      expect(invocation.chain.map((Command command) => command.name), <String>['gen', 'build']);
    });

    test('rejects an unknown command', () {
      final Cli app = _app();
      expect(() => resolveInvocation(app.commands, <String>['nope']), throwsA(isA<CliUsageError>()));
    });
  });

  group('flags', () {
    test('reads long and short forms', () {
      expect(_parse(<String>['build', 'api', '--watch']).flag('watch'), isTrue);
      expect(_parse(<String>['build', 'api', '-w']).flag('watch'), isTrue);
      expect(_parse(<String>['build', 'api']).flag('watch'), isFalse);
    });

    test('negates with the no- prefix', () {
      expect(_parse(<String>['build', 'api', '--watch', '--no-watch']).flag('watch'), isFalse);
    });

    test('inherits global flags on every command', () {
      expect(_parse(<String>['build', 'api', '--yes']).flag('yes'), isTrue);
      expect(_parse(<String>['gen', 'build', 'api', '-y']).flag('yes'), isTrue);
    });
  });

  group('typed options', () {
    test('parses text, int and enum values', () {
      final Arguments arguments = _parse(<String>['build', 'api', '-n', 'poppin', '--count=3', '--mode', 'fast']);

      expect(arguments.get(_name), 'poppin');
      expect(arguments.get(_count), 3);
      expect(arguments.get(_mode), _Mode.fast);
    });

    test('falls back to the declared default', () {
      final Arguments arguments = _parse(<String>['build', 'api']);

      expect(arguments.get(_count), 1);
      expect(arguments.get(_mode), _Mode.safe);
      expect(arguments.get(_name), isNull);
    });

    test('refuses a value outside the allowed range', () {
      expect(() => _parse(<String>['build', 'api', '--count', '42']), throwsA(isA<CliUsageError>()));
      expect(() => _parse(<String>['build', 'api', '--count', 'many']), throwsA(isA<CliUsageError>()));
    });

    test('refuses a value outside the allowed set', () {
      expect(() => _parse(<String>['build', 'api', '--mode', 'turbo']), throwsA(isA<CliUsageError>()));
    });

    test('refuses an option without a value', () {
      expect(() => _parse(<String>['build', 'api', '--name']), throwsA(isA<CliUsageError>()));
    });

    test('refuses an unknown option', () {
      expect(() => _parse(<String>['build', 'api', '--nope']), throwsA(isA<CliUsageError>()));
    });
  });

  group('positionals', () {
    test('binds declared arguments by position', () {
      final Arguments arguments = _parse(<String>['build', 'api', 'one', 'two']);

      expect(arguments.positional(_target), 'api');
      expect(arguments.positional(_extras), 'one two');
    });

    test('requires the mandatory argument', () {
      expect(() => _parse(<String>['build']), throwsA(isA<CliUsageError>()));
    });

    test('skips validation when help is requested', () {
      expect(_parse(<String>['build', '--help']).wantsHelp, isTrue);
    });

    test('stops parsing options after a bare double dash', () {
      expect(_parse(<String>['build', 'api', '--', '--watch']).rest, <String>['api', '--watch']);
    });
  });

  group('help and version', () {
    test('turns the help command into a help flag', () {
      final Cli app = _app();
      expect(resolveInvocation(app.commands, <String>['help', 'build']).wantsHelp, isTrue);
    });

    test('recognises the version flag', () {
      expect(_parse(<String>['build', 'api', '--version']).wantsVersion, isTrue);
    });
  });

  group('usage', () {
    test('lists visible commands, arguments and globals', () {
      final String usage = renderToText(Usage(app: _app()), width: 100);

      expect(usage, contains('demo <command> [options]'));
      expect(usage, contains('build'));
      expect(usage, isNot(contains('internal')));
      expect(usage, contains('--yes'));
    });

    test('shows the argument line of a leaf command', () {
      final String usage = renderToText(Usage(app: _app(), command: const _Build(), path: const <String>['build']));

      expect(usage, contains('demo build <target> [extras...] [options]'));
      expect(usage, contains('Project name.'));
      expect(usage, contains('[fast, safe]'));
      expect(usage, contains('(defaults to safe)'));
    });
  });

  group('completion', () {
    test('emits a fish script covering nested commands', () {
      final String script = renderCompletion(_app(), CompletionShell.fish);

      expect(script, contains("complete -c demo -f -n '__fish_use_subcommand' -a 'build'"));
      expect(script, contains("__fish_seen_subcommand_from gen"));
      expect(script, isNot(contains("-a 'internal'")));
    });

    test('emits zsh and bash scripts', () {
      expect(renderCompletion(_app(), CompletionShell.zsh), contains('compdef _demo demo'));
      expect(renderCompletion(_app(), CompletionShell.bash), contains('complete -F _demo demo'));
    });
  });

  group('middlewares', () {
    test('runs every middleware on the resolved path, parent first', () async {
      _Traced.calls.clear();
      final Cli app = Cli(name: 'demo', description: 'A demo CLI.', commands: const <Command>[_TracedGroup()]);

      expect(await run(app, <String>['outer', 'traced']), 0);
      expect(_Traced.calls, <String>['group', 'leaf', 'run']);
    });

    test('maps a failure to its exit code', () async {
      final Cli app = Cli(name: 'demo', description: 'A demo CLI.', commands: const <Command>[_Boom()]);

      expect(await run(app, <String>['boom']), 7);
    });

    test('maps an unknown option to the usage exit code', () async {
      final Cli app = Cli(name: 'demo', description: 'A demo CLI.', commands: const <Command>[_Boom()]);

      expect(await run(app, <String>['boom', '--nope']), 64);
    });
  });
}
