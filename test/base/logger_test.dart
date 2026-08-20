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

import 'package:scribe_tools/src/base/context.dart';
import 'package:scribe_tools/src/base/io.dart';
import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/platform.dart';
import 'package:scribe_tools/src/base/terminal.dart';
import 'package:test/test.dart';

void main() {
  group('Status', () {
    test('a silent status never writes, and still measures', () {
      final Stopwatch stopwatch = Stopwatch();
      final Status status = SilentStatus(stopwatch: stopwatch)..start();

      expect(stopwatch.isRunning, isTrue);

      status.stop();

      expect(stopwatch.isRunning, isFalse);
    });

    test('a summary status prints the message once, then the elapsed time', () {
      final StringBuffer written = StringBuffer();
      final Status status = SummaryStatus(
        message: 'Rendering templates',
        stopwatch: Stopwatch(),
        write: written.write,
      );

      status.start();
      status.start();
      status.stop();

      expect(written.toString(), startsWith('Rendering templates'));
      expect('Rendering templates'.allMatches(written.toString()).length, 1);
      expect(written.toString(), endsWith('ms\n'));
    });

    test('a finished status calls back exactly once', () {
      int finished = 0;
      SilentStatus(stopwatch: Stopwatch(), onFinish: () => finished += 1)
        ..start()
        ..stop();

      expect(finished, 1);
    });
  });

  group('StdoutLogger', () {
    StdoutLogger loggerOn(FakeStdio stdio, {bool animation = false}) => StdoutLogger(
      terminal: AnsiTerminal(
        stdio: stdio,
        platform: const FakePlatform(stdoutSupportsAnsi: true),
        animationEnabled: animation,
      ),
      stdio: stdio,
      outputPreferences: OutputPreferences.test(),
    );

    test('errors go to stderr and are remembered', () {
      final FakeStdio stdio = FakeStdio();
      final StdoutLogger logger = loggerOn(stdio);

      logger.printError('the database is unreachable');

      expect(stdio.errorOutput.toString(), contains('the database is unreachable'));
      expect(stdio.output.toString(), isEmpty);
      expect(logger.hadErrorOutput, isTrue);
    });

    test('a progress falls back to a summary when animation is off', () {
      final FakeStdio stdio = FakeStdio();
      final Status status = loggerOn(stdio).startProgress('Compiling');

      expect(status, isA<SummaryStatus>());

      status.stop();

      expect(stdio.output.toString(), startsWith('Compiling'));
    });

    test('a progress becomes a spinner when animation is on', () {
      final FakeStdio stdio = FakeStdio(hasTerminalOverride: true);

      expect(loggerOn(stdio, animation: true).startProgress('Compiling'), isA<SpinnerStatus>());
    });

    test('starting a second progress stops the first', () {
      final FakeStdio stdio = FakeStdio();
      final StdoutLogger logger = loggerOn(stdio);

      logger.startProgress('First');
      logger.startProgress('Second');

      expect(stdio.output.toString(), contains('First'));
      expect(stdio.output.toString(), contains('Second'));
    });
  });

  group('BufferLogger', () {
    test('it keeps each channel apart', () {
      final BufferLogger logger = BufferLogger();

      logger.printStatus('status');
      logger.printError('error');
      logger.printWarning('warning');
      logger.printTrace('trace');

      expect(logger.statusText, 'status\n');
      expect(logger.errorText, 'error\n');
      expect(logger.warningText, 'warning\n');
      expect(logger.traceText, 'trace\n');
    });
  });

  group('VerboseLogger', () {
    test('it stamps every line and promotes traces to the delegate', () {
      final BufferLogger buffer = BufferLogger();
      final VerboseLogger logger = VerboseLogger(buffer);

      logger.printTrace('resolving dependencies');

      expect(logger.isVerbose, isTrue);
      expect(buffer.statusText, contains('resolving dependencies'));
      expect(buffer.statusText, matches(RegExp(r'^\[.*\] ')));
    });

    test('an empty line is dropped rather than stamped', () {
      final BufferLogger buffer = BufferLogger();

      VerboseLogger(buffer).printStatus('   ');

      expect(buffer.statusText, isEmpty);
    });
  });

  group('AppContext', () {
    test('an override is visible inside the zone and gone outside', () async {
      final BufferLogger injected = BufferLogger();

      expect(AppContext.current.get<Logger>(), isNull);

      await AppContext.current.run<void>(
        name: 'test',
        overrides: <Type, Generator>{Logger: () => injected},
        body: () {
          expect(AppContext.current.get<Logger>(), same(injected));
        },
      );

      expect(AppContext.current.get<Logger>(), isNull);
    });

    test('a generator runs once, however many times it is read', () async {
      int built = 0;

      await AppContext.current.run<void>(
        overrides: <Type, Generator>{
          Logger: () {
            built += 1;
            return BufferLogger();
          },
        },
        body: () {
          AppContext.current.get<Logger>();
          AppContext.current.get<Logger>();
        },
      );

      expect(built, 1);
    });

    test('a cycle between two generators is reported, not hung', () async {
      await AppContext.current.run<void>(
        overrides: <Type, Generator>{
          Logger: () => AppContext.current.get<Terminal>() == null ? BufferLogger() : BufferLogger(),
          Terminal: () => AppContext.current.get<Logger>() == null ? TestTerminal() : TestTerminal(),
        },
        body: () {
          expect(() => AppContext.current.get<Logger>(), throwsA(isA<ContextDependencyCycleException>()));
        },
      );
    });
  });
}
