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

import 'package:interact/interact.dart' as interact;
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/sdk_target.dart';

/// Settles which SDK a new project is written against.
///
/// The choices come from the framework on disk, never from a list in here, so
/// an SDK that appears in `scribe/sdk/` appears in the menu without this file
/// changing — see [SdkCatalog].
///
/// Four ways out, in this order: what `--sdk` named, the only SDK available,
/// what the user picked from the menu, or the default. Each fallback says why
/// it was taken, because a project silently created against the wrong SDK is
/// found much later.
class SdkChoice {
  const SdkChoice({required this.catalog, required this.commandName, required this.assumeYes});

  /// What the framework next to the caller offers.
  final SdkCatalog catalog;

  /// The command the refusals are blamed on.
  final String commandName;

  /// Whether `--yes` was passed, which forbids asking.
  final bool assumeYes;

  /// The SDK to build against, [asked] deciding it outright when it is given.
  ///
  /// Throws a [UsageError] when [asked] is not an SDK the framework carries,
  /// and a [ToolExit] when it names one that cannot be built on.
  Future<SdkTarget> resolve(String? asked) async {
    if (asked != null) return _named(asked);
    if (!catalog.isKnown) return _fallback('no scribe checkout above this directory');

    for (final SdkTarget ignored in catalog.ignored) {
      globals.logger.printTrace('skipping sdk/${ignored.name}: ${ignored.caveat}');
    }

    final List<SdkTarget> choices = catalog.offerable;
    if (choices.isEmpty) return _fallback('${catalog.root!.path} holds no usable SDK');

    if (choices.length == 1) {
      globals.logger.printStatus('Only one SDK is available, ${choices.single.name}.');
      return choices.single;
    }

    if (!_canAsk) return _fallback('nothing to ask on', choices: choices);

    return _ask(choices);
  }

  /// Whether a menu can be shown at all.
  ///
  /// The guard is raw input rather than merely having a terminal: a pseudo
  /// terminal can claim to be one and still fail to leave line mode, which used
  /// to kill the command right after it had drawn the menu.
  bool get _canAsk => globals.terminal.supportsRawInput && !assumeYes;

  SdkTarget _named(String asked) {
    if (!catalog.isKnown) return SdkTarget.assumed(asked.trim().toLowerCase());

    final SdkTarget? found = catalog.byName(asked);
    if (found == null) {
      throwUsageError(
        '"$asked" is not an SDK this framework carries. '
        'The choices come from ${catalog.root!.path}: ${catalog.names.join(', ')}.',
        command: commandName,
      );
    }

    if (!found.isRecognised || found.isEmpty) {
      throwToolExit('${found.caveat}\nPick another SDK: ${catalog.names.join(', ')}.');
    }

    return found;
  }

  /// The default SDK, saying [why] it was taken rather than asking.
  ///
  /// The one from [choices] is preferred when it is there, so the project is
  /// built against the framework's real directory instead of an assumed one.
  SdkTarget _fallback(String why, {List<SdkTarget> choices = const <SdkTarget>[]}) {
    globals.logger.printStatus('Using the $kDefaultSdkName SDK: $why to pick another.');

    for (final SdkTarget candidate in choices) {
      if (candidate.name == kDefaultSdkName) return candidate;
    }

    return const SdkTarget.assumed(kDefaultSdkName);
  }

  /// The menu, cursor on the default when it is one of [choices].
  ///
  /// Only the names are listed. A menu that annotates its own entries asks to
  /// be read before it can be answered, and there are two lines in it.
  Future<SdkTarget> _ask(List<SdkTarget> choices) async {
    final int defaultIndex = choices.indexWhere((SdkTarget target) => target.name == kDefaultSdkName);

    final int picked = interact.Select(
      prompt: 'Which SDK will the endpoints be written against?',
      options: <String>[for (final SdkTarget target in choices) target.label],
      initialIndex: defaultIndex < 0 ? 0 : defaultIndex,
    ).interact();

    return choices[picked];
  }
}
