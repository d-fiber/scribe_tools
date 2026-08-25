// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/template.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/capacity.dart';
import 'package:scribe_tools/src/ops/fragments.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/sizing_rules.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';

/// The templates rendered on every run, in the order Compose reads them.
///
/// The order matters: each later document overrides the earlier ones, so the
/// base compose comes first and the sizing documents patch it.
const List<String> composeTemplates = <String>[composeTemplate, 'resources.yaml', 'replicas.yaml', 'tuning.yaml'];

/// The fragment a package uses to patch a service of the base, rather than to
/// declare one of its own.
const String overlayTemplate = 'overlay.yaml';

/// The document an overlay is merged into, since it has no base of its own.
const String overlayBase = 'name: "{{app_name_snake}}"\nservices:\n';

/// The profile the project's own worker container starts under.
///
/// No package declares it: the worker belongs to the socle, and whether it runs
/// is a project decision rather than a consequence of a selection.
const String workerProfile = 'worker';

/// The file name an overlay labelled [label] is written to.
///
/// A label names the package and, when the fragment sits in a subject directory,
/// the subject after it, so the slash it may carry becomes a dash here.
String overlayFileName(String label) => 'overlay.${label.replaceAll('/', '-')}.yaml';

/// What a render produces, which is more than files.
///
/// The profiles are not written anywhere: Compose takes them as `--profile`
/// arguments, so they have to travel next to the documents rather than inside
/// them. A caller that starts the stack needs both or it starts the wrong half.
class ComposeDocuments {
  /// Holds the [files] Compose reads and the [profiles] it is started with.
  const ComposeDocuments({required this.files, required this.profiles});

  /// The documents to pass Compose in `-f`, in the order it must read them.
  final List<File> files;

  /// The Compose profiles to switch on, sorted.
  final List<String> profiles;
}

/// The compose documents of a project, rendered from the framework's templates.
///
/// The framework's own tree is never written to: the templates and the package
/// fragments are fixed, and everything this produces lands under the project's
/// generated directory.
class ComposeRender {
  /// Renders [project], the one the command is running in when none is named.
  ComposeRender({Project? project}) : project = project ?? globals.project;

  /// The project being rendered, whose `config.yaml` decides the selection.
  final Project project;

  /// Renders every template and every overlay, and returns what Compose needs.
  Future<ComposeDocuments> render(Hardware hardware) async {
    final Directory target = project.generated.ops;
    if (!target.existsSync()) target.createSync(recursive: true);

    final Packages packages = Packages.load();
    final List<Package> active = packages.active;

    final List<String> profiles = <String>[...Packages.profilesOf(active), if (project.manifest.worker) workerProfile]
      ..sort();

    final SizingRules rules = SizingRules(
      hardware,
      Capacity.load(project: project, mounted: active, profiles: profiles.toSet()),
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

    _reportSelection(packages, active, profiles);

    final List<File> rendered = <File>[
      for (final String name in composeTemplates)
        await _renderTemplate(name, values, target, packages.fragmentsFor(name, active)),
    ];

    // One file per overlay, never one per package: two overlays that patch the
    // same socle service would produce two identical keys in one document, and
    // it is `docker compose` that knows how to combine them.
    int position = 1;
    for (final Package package in active) {
      for (final YamlFragment overlay in package.fragmentsFor(overlayTemplate)) {
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
      'dashboard': project.manifest.dashboard,
      'api_url': project.manifest.apiUrl,
    };
  }

  void _reportSelection(Packages packages, List<Package> active, List<String> profiles) {
    final List<String> dropped = <String>[
      for (final Package package in packages.all)
        if (!active.contains(package)) package.name,
    ];

    globals.logger.printStatus(
      dropped.isEmpty
          ? '${active.length} package(s) mounted: all of them'
          : '${active.length} package(s) mounted, dropped: ${dropped.join(', ')}',
    );
    globals.logger.printStatus('profiles: ${profiles.isEmpty ? 'none, the socle alone' : profiles.join(', ')}');
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
