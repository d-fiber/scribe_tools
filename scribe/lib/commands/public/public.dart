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
import 'templates/hosting_strings.dart';
import 'templates/mail_strings.dart';
import 'templates/sms_strings.dart';

const List<String> _targets = <String>['templates', 'hostings'];

class PublicCommand extends Command {
  const PublicCommand();

  @override
  String get name => 'public';

  @override
  String get description => 'Generate derived files under lib/public/.';

  @override
  List<Middleware> get middlewares => const <Middleware>[requireInitializedProject];

  @override
  String get usage => '(-g|--generate) templates [-a|--all|-m|--mails|-s|--sms] | (-g|--generate) hostings';

  @override
  List<Flag> get flags => const <Flag>[
    Flag('generate', abbr: 'g', help: 'generate derived files for a lib/public/ target.'),
    Flag('all', abbr: 'a', help: 'templates only: generate every mail + sms subtree (mails + sms).'),
    Flag('mails', abbr: 'm', help: 'templates only: generate lib/public/mails/ only.'),
    Flag('sms', abbr: 's', help: 'templates only: generate lib/public/sms/ only.'),
  ];

  @override
  Future<void> run(Context cli) async {
    final Arguments arguments = cli.arguments;
    if (!arguments.flag('generate')) cli.usageError('Pass --generate/-g.');

    final String? target = arguments.rest.length == 1 ? arguments.rest.single : null;
    if (target == null || !_targets.contains(target)) {
      cli.usageError('Expected exactly one target: ${_targets.join('|')}.');
    }

    if (target == 'hostings') {
      await generateHostingStrings();
      return;
    }

    final bool all = arguments.flag('all');
    final bool mails = arguments.flag('mails');
    final bool sms = arguments.flag('sms');
    if (!all && !mails && !sms) cli.usageError('Pass one of -a/--all, -m/--mails, -s/--sms.');

    if (all || mails) await generateMailTemplateStrings();
    if (all || sms) await generateSmsTemplateStrings();
  }
}
