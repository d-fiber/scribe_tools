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

import '../../core/console/console.dart';
import '../../core/project/gate.dart';
import '_internal/extension_feature.dart';
import 'cron/cron_extension.dart';
import 'hooks/hooks_extension.dart';
import 'queue/queue_extension.dart';

const Map<String, ExtensionFeature> _features = <String, ExtensionFeature>{
  'hooks': HooksExtension(),
  'queue': QueueExtension(),
  'cron': CronExtension(),
};

class ExtensionsCommand extends Command {
  const ExtensionsCommand();

  @override
  String get name => 'extensions';

  @override
  String get description =>
      'Scaffold or remove an optional lib/extensions/event_driven/ feature (hooks, queue, cron).';

  @override
  List<Middleware> get middlewares => const <Middleware>[requireInitializedProject];

  @override
  String get usage => '((-s|--set)|(-u|--unset)) <${_features.keys.join('|')}>';

  @override
  List<Flag> get flags => const <Flag>[
    Flag(
      'set',
      abbr: 's',
      help: 'Scaffold the feature under lib/extensions/<name>/ (only if not already present).',
    ),
    Flag('unset', abbr: 'u', help: 'Remove the feature under lib/extensions/<name>/.'),
    Flag(
      'yes',
      abbr: 'y',
      help: 'Skip the confirmation prompt (--unset queue/cron only, both destructive on hand-written code).',
    ),
  ];

  @override
  Future<void> run(Context cli) async {
    final bool doSet = cli.arguments.flag('set');
    final bool doUnset = cli.arguments.flag('unset');
    if (doSet == doUnset) cli.usageError('Pass exactly one of --set/-s or --unset/-u.');

    final String? target = cli.arguments.rest.length == 1 ? cli.arguments.rest.single : null;
    final ExtensionFeature? feature = target == null ? null : _features[target];
    if (feature == null) cli.usageError('Expected exactly one feature: ${_features.keys.join('|')}.');

    if (doSet) return feature.set(cli.log);
    return feature.unset(cli.log, yes: cli.arguments.flag('yes'));
  }
}
