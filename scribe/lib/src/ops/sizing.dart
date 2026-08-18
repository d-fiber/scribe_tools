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

import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/template.dart';
import 'package:scribe/src/dependencies.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/ops/capacity.dart';
import 'package:scribe/src/ops/fragments.dart';
import 'package:scribe/src/ops/hardware.dart';
import 'package:scribe/src/ops/sizing_rules.dart';
import 'package:scribe/src/project.dart';

/// The templates rendered on every run, in the order Compose reads them.
///
/// The order matters: each later document overrides the earlier ones, so the
/// base compose comes first and the sizing documents patch it.
const List<String> composeTemplates = <String>[
  'docker-compose.yaml',
  'resources.yaml',
  'replicas.yaml',
  'tuning.yaml',
];

/// The fragment a module uses to patch a service of the base, rather than to
/// declare one of its own.
const String overlayTemplate = 'overlay.yaml';

/// The document an overlay is merged into, since it has no base of its own.
const String overlayBase = 'name: "{{app_name_snake}}"\nservices:\n';

/// The profile the project's own worker container starts under.
///
/// No module declares it: the worker belongs to the socle, and whether it runs
/// is a project decision rather than a consequence of a selection.
const String workerProfile = 'worker';

/// The file name an overlay of [path] is written to.
String overlayFileName(String path) => 'overlay.${path.replaceAll('/', '-')}.yaml';

/// What a render produces, which is more than files.
///
/// The profiles are not written anywhere: Compose takes them as `--profile`
/// arguments, so they have to travel next to the documents rather than inside
/// them. A caller that starts the stack needs both or it starts the wrong half.
class ComposeDocuments {
  const ComposeDocuments({required this.files, required this.profiles});

  /// The documents to pass Compose in `-f`, in the order it must read them.
  final List<File> files;

  /// The Compose profiles to switch on, sorted.
  final List<String> profiles;
}

/// The compose documents of a project, rendered from the framework's templates.
///
/// The framework's own tree is never written to: the templates and the module
/// fragments are fixed, and everything this produces lands under the project's
/// generated directory.
class ComposeRender {
  ComposeRender({Project? project}) : project = project ?? globals.project;

  /// The project being rendered, whose `config.yaml` decides the selection.
  final Project project;

  /// Renders every template and every overlay, and returns what Compose needs.
  Future<ComposeDocuments> render(Hardware hardware) async {
    final Directory target = project.generated.ops;
    if (!target.existsSync()) target.createSync(recursive: true);

    final Dependencies dependencies = Dependencies.load();
    final List<Dependency> active = dependencies.active;

    final List<String> profiles = <String>[
      ...Dependencies.profilesOf(active),
      if (project.manifest.worker) workerProfile,
    ]..sort();

    final SizingRules rules = SizingRules(
      hardware,
      Capacity.load(project: project, modules: active, profiles: profiles.toSet()),
    );
    final Map<String, String> values = <String, String>{...rules.resolve(), ..._identity()};

    globals.logger.printTrace('[sizing] hardware $hardware');
    globals.logger.printStatus(
      'api x${rules.apiReplicas}, rest x${rules.restReplicas}, storage x${rules.storageReplicas}, '
      'db ${values['db_mem_limit']} (shared_buffers ${values['db_shared_buffers']}), '
      'pool ${values['rest_db_pool']}/instance',
    );

    if (hardware.memoryGb < 4 || hardware.cores < 2) {
      globals.logger.printWarning('very small machine ($hardware), the stack may not start.');
    }

    _reportSelection(dependencies, active, profiles);

    final List<File> rendered = <File>[
      for (final String name in composeTemplates)
        await _renderTemplate(name, values, target, dependencies.fragmentsFor(name, active)),
    ];

    // One file per overlay, never one per module: two overlays that patch the
    // same socle service would produce two identical keys in one document, and
    // it is `docker compose` that knows how to combine them.
    int position = 1;
    for (final Dependency dependency in active) {
      for (final YamlFragment overlay in dependency.fragmentsFor(overlayTemplate)) {
        rendered.insert(
          position++,
          await _write(overlayFileName(overlay.label), overlayBase, values, target, <YamlFragment>[overlay]),
        );
      }
    }

    return ComposeDocuments(files: rendered, profiles: profiles);
  }

  /// The values that name the project rather than size it.
  Map<String, String> _identity() {
    final String name = project.manifest.name;

    return <String, String>{
      'app_name': name,
      'app_name_snake': name.toSnakeCase(),
      'sdk_root': './${p.basename(project.sdk.path)}',
      'alchemy_dir': p.basename(project.generated.path),
    };
  }

  void _reportSelection(Dependencies dependencies, List<Dependency> active, List<String> profiles) {
    final List<String> dropped = <String>[
      for (final Dependency dependency in dependencies.all)
        if (!active.contains(dependency)) dependency.path,
    ];

    globals.logger.printStatus(
      dropped.isEmpty
          ? '${active.length} dependency(ies) mounted: all of them'
          : '${active.length} dependency(ies) mounted, dropped: ${dropped.join(', ')}',
    );
    globals.logger.printStatus(
      'profiles: ${profiles.isEmpty ? 'none, the socle alone' : profiles.join(', ')}',
    );
  }

  Future<File> _renderTemplate(
    String name,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments,
  ) async {
    final File source = project.sdk.opsTemplates.childDirectory('docker').childFile(name);
    if (!source.existsSync()) {
      throwToolExit('No template at ${source.path}');
    }

    return _write(name, await source.readAsString(), values, target, fragments);
  }

  Future<File> _write(
    String name,
    String source,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments,
  ) async {
    final File destination = target.childFile(name);
    await destination.writeAsString(renderTemplate(name, mergeYamlDocuments(source, fragments), values));

    return destination;
  }
}
