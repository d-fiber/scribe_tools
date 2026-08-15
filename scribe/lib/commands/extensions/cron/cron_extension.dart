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

const String _kCronTs =
    '''
$_kHeader
// Agrégateur des cronjobs du projet, miroir de
// lib/extensions/event_driven/hooks/hooks.ts. Un `import "./jobs/<nom>.ts";`
// par cron : le fichier appelle `defineCron` au chargement, ce qui l'arme.
//
// Chargé par `extensions.cron()` juste avant `cronRunner.start()`. Vide tant
// qu'aucun cronjob métier n'est déclaré — le rapport au démarrage
// (`cronRegistry.report()`) le dira explicitement.
''';

const String _kCustomTemplateTs =
    '''
$_kHeader
// Template pour un nouveau cronjob, voir .claude/lib/extensions/event_driven/cron/global.md :
//
//   cp lib/extensions/event_driven/cron/custom/_template/_template.ts \\
//      lib/extensions/event_driven/cron/jobs/widget_cleanup.ts
//   # puis adapte le nom, le schedule et le corps, et ajoute
//   #   import "./jobs/widget_cleanup.ts";
//   # dans lib/extensions/event_driven/cron/cron.ts
//
// Un cron est déclaré ET traité par lib/ : `defineCron` fait les deux en un
// seul appel, dans un seul fichier. Ni classe à étendre, ni `new`, ni fichier de
// handler séparé.
//
// Trois plannings, au choix :
//   cron("0 3 * * *", CronTimezone.EuropeParis)      expression cron, timezone obligatoire
//   every(Time.hours(6))                             intervalle, minutes entières
//   at(CronTimezone.EuropeParis, "00:00", "12:00")   une ou plusieurs heures fixes

import { cron, CronTimezone, defineCron } from "@scribe/host/runtime/event_driven/cron/mod.ts";

export const widgetCleanup = defineCron(
  {
    name: "widget:cleanup",
    schedule: cron("0 3 * * *", CronTimezone.EuropeParis),
    // timeout: Time.minutes(30)   ← 10 minutes par défaut. C'est aussi la durée
    // du verrou Redis de l'occurrence : un job plus long doit l'augmenter.
  },
  async () => {
    await Promise.resolve();
  },
);
''';

class CronExtension extends ExtensionFeature {
  const CronExtension();

  @override
  final String name = 'cron';

  @override
  Future<void> set(Log log) async {
    final Directory dir = Paths.project.extensions.eventDriven.cron.directory;
    final File aggregator = File(p.join(dir.path, 'cron.ts'));

    if (aggregator.existsSync()) {
      log.info('lib/extensions/event_driven/cron/ already set, nothing to do.');
      return;
    }

    final Directory templateDir = Directory(p.join(dir.path, 'custom', '_template'));
    templateDir.createSync(recursive: true);

    aggregator.writeAsStringSync(_kCronTs);
    File(p.join(templateDir.path, '_template.ts')).writeAsStringSync(_kCustomTemplateTs);

    log.info(
      'lib/extensions/event_driven/cron/ scaffolded. Discovered automatically by '
      'extensions.cron() on next process start — nothing else to wire.',
    );
  }

  @override
  Future<void> unset(Log log, {required bool yes}) async {
    final Directory dir = Paths.project.extensions.eventDriven.cron.directory;

    if (!dir.existsSync()) {
      log.info('lib/extensions/event_driven/cron/ is not set, nothing to do.');
      return;
    }

    if (!yes) {
      log.warn(
        'This deletes ${dir.path} entirely, including any custom cronjob you '
        'may have added under custom/. Re-run with --yes to confirm.',
      );
      return;
    }

    dir.deleteSync(recursive: true);

    log.info(
      'lib/extensions/event_driven/cron/ removed. Nothing else to unwire: '
      'runtime/extensions.ts discovers it via a dynamic import, which '
      'now simply fails silently.',
    );
  }
}
