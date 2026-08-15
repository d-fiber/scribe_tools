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

const String _kQueueTs =
    '''
$_kHeader
// Agrégateur des queues du projet, miroir de cron/cron.ts et hooks/hooks.ts.
// Un `import "./jobs/<nom>.ts";` par queue : le fichier appelle `defineQueue`
// au chargement, ce qui déclare la queue ET arme son corps.
//
// Chargé par `extensions.queue()` depuis
// scribe/host/api/internal/queue/index.ts, juste avant que le service
// expose /drain, /drain/:name et /status.
''';

const String _kCustomTemplateTs =
    '''
$_kHeader
// Template pour une nouvelle queue, voir .claude/lib/extensions/event_driven/queue/global.md :
//
//   cp lib/extensions/event_driven/queue/custom/_template/_template.ts \\
//      lib/extensions/event_driven/queue/jobs/emails.ts
//   # puis adapte le nom, le type du job et le corps, et ajoute
//   #   import "./jobs/emails.ts";
//   # dans lib/extensions/event_driven/queue/queue.ts
//
// `defineQueue` declare la queue et arme son corps en un seul appel, dans un
// seul fichier — comme `defineCron`. L'objet rendu porte le cote producteur
// (`push`, `pushMany`) ; le corps est declenche par le runner ou par
// POST /queue/drain[/:name].

import { defineQueue } from "@scribe/host/runtime/event_driven/queue/mod.ts";

export interface WidgetJob {
  readonly widgetId: string;
}

export const widgetQueue = defineQueue<WidgetJob>(
  { name: "widget:process" },
  async (job) => {
    await Promise.resolve(job.widgetId);
  },
);

// Traitement par lots (un job isole n'a pas de valeur : logs, envois groupes) :
//
//   export const widgetQueue = defineQueue<WidgetJob>(
//     { name: "widget:process", batch: { lingerMs: 3_000 } },
//     async (jobs) => { /* jobs: readonly WidgetJob[] */ },
//   );
//
// Pousser depuis n'importe ou dans lib/ :
//   await widgetQueue.push({ widgetId });
''';

class QueueExtension extends ExtensionFeature {
  const QueueExtension();

  @override
  final String name = 'queue';

  @override
  Future<void> set(Log log) async {
    final Directory dir = Paths.project.extensions.eventDriven.queue.directory;
    final File aggregator = File(p.join(dir.path, 'queue.ts'));

    if (aggregator.existsSync()) {
      log.info('lib/extensions/event_driven/queue/ already set, nothing to do.');
      return;
    }

    final Directory templateDir = Directory(p.join(dir.path, 'custom', '_template'));
    templateDir.createSync(recursive: true);

    aggregator.writeAsStringSync(_kQueueTs);
    File(p.join(templateDir.path, '_template.ts')).writeAsStringSync(_kCustomTemplateTs);

    log.info(
      'lib/extensions/event_driven/queue/ scaffolded. Discovered automatically by '
      'extensions.queue() on next call — nothing else to wire.',
    );
  }

  @override
  Future<void> unset(Log log, {required bool yes}) async {
    final Directory dir = Paths.project.extensions.eventDriven.queue.directory;

    if (!dir.existsSync()) {
      log.info('lib/extensions/event_driven/queue/ is not set, nothing to do.');
      return;
    }

    if (!yes) {
      log.warn(
        'This deletes ${dir.path} entirely, including any custom queue you '
        'may have added under custom/. Re-run with --yes to confirm.',
      );
      return;
    }

    dir.deleteSync(recursive: true);

    log.info(
      'lib/extensions/event_driven/queue/ removed. Nothing else to unwire: '
      'runtime/extensions.ts discovers it via a dynamic import, which '
      'now simply fails silently.',
    );
  }
}
