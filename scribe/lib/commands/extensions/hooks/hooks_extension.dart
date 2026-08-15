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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/logger.dart';
import '../../../core/file_system_entity/paths.dart';
import '../_internal/extension_feature.dart';

const String _kHeader = '''
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
// Fiber BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.
''';

const String _kHooksTs =
    '''
$_kHeader
import { HookClient } from "@scribe/host/runtime/event_driven/hook/mod.ts";

// Les abonnements. Un import = un fichier de handlers chargé, donc enregistré :
// c'est le graphe de modules qui fait le travail, aucun import dynamique.
import "./handlers/account/deleted.ts";
import "./handlers/account/device-delete.ts";
import "./handlers/account/device-insert.ts";
import "./handlers/account/sign-out.ts";
import "./handlers/account/update-email.ts";
import "./handlers/account/update-password.ts";
import "./handlers/account/update-phone.ts";
import "./handlers/auth/reset-password.ts";
import "./handlers/auth/sign-in.ts";
import "./handlers/auth/sign-up.ts";

// Miroir de ProjectRealtimeClient : on hérite des hooks du kernel et on
// déclare ici les hooks custom du projet.
class ProjectHookClient extends HookClient {}

export const hooks = new ProjectHookClient();
''';

String _handlerTs(String exportLine) =>
    '''
$_kHeader
import { hooks } from "@scribe/host/runtime/event_driven/hook/mod.ts";

export const $exportLine
''';

const String _kCustomTemplateTs =
    '''
$_kHeader
// Template pour un nouveau hook custom, voir .claude/lib/extensions/event_driven/hooks/global.md :
//
//   cp -r lib/extensions/event_driven/hooks/custom/_template lib/extensions/event_driven/hooks/custom/foo
//   mv lib/extensions/event_driven/hooks/custom/foo/_template.ts lib/extensions/event_driven/hooks/custom/foo/foo.ts
//   # remplace Widget→Foo, adapte les champs du payload
//
// Pas de registry.ts, pas de `koko gen code` : contrairement aux queues (moteur Redis
// Streams partagé dans scribe/), un hook custom est une instance autonome, 100%
// lib/ un simple import suffit à la déclarer, la déclencher et la recevoir.
//
// Une seule primitive, `Hook<T, R = void>` :
// - side-effect, ne retourne rien : `new Hook<WidgetCreatedPayload>()` (voir ci-dessous).
// - retourne une décision (`R`), avec une valeur par défaut si aucun handler n'est
//   enregistré : `new Hook<WidgetCreatedPayload, boolean>(true)`.

import { Hook } from "@scribe/host/runtime/event_driven/hook/hook.ts";

export interface WidgetCreatedPayload {
  readonly widgetId: string;
}

// Déclenché depuis lib/api/{admin,app}/... :
//   import { widgetCreatedHook } from "@app/extensions/event_driven/hooks/custom/widget/widget.ts";
//   await widgetCreatedHook.run({ widgetId });
//
// Reçu en ajoutant lib/extensions/event_driven/hooks/handlers/foo.ts :
//   export const onWidgetCreated = widgetCreatedHook.on(async (payload) => { ... });
// puis en l'important dans index.ts (import "./handlers/foo.ts";).
export const widgetCreatedHook = new Hook<WidgetCreatedPayload>();
''';

class HooksExtension extends ExtensionFeature {
  const HooksExtension();

  @override
  final String name = 'hooks';

  @override
  Future<void> set(Log log) async {
    final Directory dir = Paths.project.extensions.eventDriven.hooks.directory;
    final File aggregator = File(p.join(dir.path, 'hooks.ts'));

    if (aggregator.existsSync()) {
      log.info('lib/extensions/event_driven/hooks/ already set, nothing to do.');
      return;
    }

    final Directory authDir = Directory(p.join(dir.path, 'handlers', 'auth'));
    final Directory accountDir = Directory(p.join(dir.path, 'handlers', 'account'));
    final Directory templateDir = Directory(p.join(dir.path, 'custom', '_template'));
    authDir.createSync(recursive: true);
    accountDir.createSync(recursive: true);
    templateDir.createSync(recursive: true);

    aggregator.writeAsStringSync(_kHooksTs);

    File(
      p.join(authDir.path, 'sign-in.ts'),
    ).writeAsStringSync(_handlerTs('onSignIn = hooks.auth.signIn.on(async (_payload) => {});'));
    File(
      p.join(authDir.path, 'sign-up.ts'),
    ).writeAsStringSync(_handlerTs('onSignUp = hooks.auth.signUp.on(async (_payload) => {});'));
    File(
      p.join(authDir.path, 'reset-password.ts'),
    ).writeAsStringSync(_handlerTs('onResetPassword = hooks.auth.resetPassword.on(async (_payload) => {});'));

    File(
      p.join(accountDir.path, 'deleted.ts'),
    ).writeAsStringSync(_handlerTs('onDeleted = hooks.account.deleted.on(async (_userId) => {});'));
    File(
      p.join(accountDir.path, 'sign-out.ts'),
    ).writeAsStringSync(_handlerTs('onSignOut = hooks.account.signOut.on(async (_payload) => {});'));
    File(
      p.join(accountDir.path, 'update-password.ts'),
    ).writeAsStringSync(_handlerTs('onUpdatePassword = hooks.account.updatePassword.on(async (_payload) => {});'));
    File(
      p.join(accountDir.path, 'update-email.ts'),
    ).writeAsStringSync(_handlerTs('onUpdateEmail = hooks.account.updateEmail.on(async (_payload) => {});'));
    File(
      p.join(accountDir.path, 'update-phone.ts'),
    ).writeAsStringSync(_handlerTs('onUpdatePhone = hooks.account.updatePhone.on(async (_payload) => {});'));
    File(
      p.join(accountDir.path, 'device-insert.ts'),
    ).writeAsStringSync(_handlerTs('onDeviceInsert = hooks.account.deviceInsert.on(async (_payload) => {});'));
    File(
      p.join(accountDir.path, 'device-delete.ts'),
    ).writeAsStringSync(_handlerTs('onDeviceDelete = hooks.account.deviceDelete.on(async (_payload) => {});'));

    File(p.join(templateDir.path, '_template.ts')).writeAsStringSync(_kCustomTemplateTs);

    log.info(
      'lib/extensions/event_driven/hooks/ scaffolded. Import '
      '"@app/extensions/event_driven/hooks/hooks.ts" from lib/api/*/index.ts '
      'to wire it — static import, so a broken handler fails at boot.',
    );
  }

  @override
  Future<void> unset(Log log, {required bool yes}) async {
    final Directory dir = Paths.project.extensions.eventDriven.hooks.directory;

    if (!dir.existsSync()) {
      log.info('lib/extensions/event_driven/hooks/ is not set, nothing to do.');
      return;
    }

    dir.deleteSync(recursive: true);

    log.info(
      'lib/extensions/event_driven/hooks/ removed. Retire aussi son import '
      'de lib/api/*/index.ts : il est statique, donc le build échouera tant '
      "qu'il pointe vers un dossier supprimé.",
    );
  }
}
