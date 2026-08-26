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
import 'package:scribe_tools/src/ops/gateway.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/proxy.dart';
import 'package:scribe_tools/src/ops/sizing_rules.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/templates.dart';

/// The templates rendered on every run, in the order Compose reads them.
///
/// The order matters: each later document overrides the earlier ones, so the
/// base compose comes first and the sizing documents patch it.
const List<String> composeTemplates = <String>[composeTemplate, 'resources.yaml', 'replicas.yaml', 'tuning.yaml'];

/// The fragment a package uses to patch a service of the base, rather than to
/// declare one of its own.
const String overlayTemplate = 'overlay.yaml';

/// The Dockerfiles the socle builds from, copied beside the rendered documents.
const List<String> dockerfileNames = <String>['Dockerfile.api', 'Dockerfile.functions'];

/// The SQL the cluster runs before it accepts a connection.
///
/// It is the socle's own provisioning and not a package's: the passwords of the
/// roles the images log in as, and the database settings a package reads back.
/// A package carries its own SQL under `db/`, and mounts it beside these.
const List<String> provisioningSqlNames = <String>['roles.sql', 'jwt.sql'];

/// The document an overlay is merged into, since it has no base of its own.
const String overlayBase = 'name: "{{app_name_snake}}"\nservices:\n';

/// The profile the project's own worker container starts under.
///
/// No package declares it: the worker belongs to the socle, and whether it runs
/// is a project decision rather than a consequence of a selection.
const String workerProfile = 'worker';

/// The address the host reaches the worker on, inside the compose network.
///
/// It is the worker service's own name and the port its command listens on, so
/// it holds as long as those two do. The rendered value is empty when no worker
/// is started, which the host reads as there being none: rendering it rather
/// than reading it from the caller's environment is what keeps the profile and
/// the address from disagreeing.
const String workerEndpoint = 'http://worker:8787';

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
  /// Holds what Compose reads and what it has to be told to read it with.
  const ComposeDocuments({
    required this.files,
    required this.profiles,
    required this.projectDirectory,
    required this.projectName,
  });

  /// The documents to pass Compose in `-f`, in the order it must read them.
  final List<File> files;

  /// The Compose profiles to switch on, sorted.
  final List<String> profiles;

  /// The absolute path every relative path inside the documents resolves against.
  ///
  /// It is the project root, and the documents no longer sit inside it, so an
  /// invocation without `--project-directory` resolves thirty-three mounts
  /// against the wrong root and every one of them lands somewhere that does not
  /// exist.
  final String projectDirectory;

  /// The name Docker knows this stack by, taken from `config.yaml`.
  final String projectName;
}

/// The compose documents of a project, rendered from the templates the tool ships.
///
/// Neither the tool's own tree nor the framework's is written to: the templates
/// and the package fragments are fixed, and everything this produces lands under
/// the project's generated directory.
class ComposeRender {
  /// Renders [project], the one the command is running in when none is named.
  ComposeRender({Project? project, this.withWorker = false, this.targetName}) : project = project ?? globals.project;

  /// The deployment target this render is for, or null for the machine at hand.
  ///
  /// It names the machine in `config.yaml` and says whether the sizing may cap
  /// the cores. Rendering from a workstation for a server without it sizes the
  /// server like the workstation, which is silent and wrong.
  final String? targetName;

  /// Whether the project's code is asked to run in a container of its own.
  ///
  /// It is decided when the stack is started and not held by the manifest,
  /// because the host only talks to a worker when `WORKER_ENDPOINT` names one:
  /// two switches for one thing can disagree, and one of them living in a file
  /// the other never reads is how they do.
  final bool withWorker;

  /// The project being rendered, whose `config.yaml` decides the selection.
  final Project project;

  /// Renders every template and every overlay, and returns what Compose needs.
  Future<ComposeDocuments> render(Hardware detected) async {
    final Hardware hardware = targetName == null ? detected : (project.manifest.machineOf(targetName!) ?? detected);
    final bool cpuCap = targetName != null && project.manifest.cpuCapOf(targetName!);

    // Outside the project, and emptied first: an overlay whose package the
    // project has since dropped would otherwise survive, and the only practical
    // way to list the documents again is a glob, so the dead one would be
    // mounted with the live ones.
    final Directory target = StackLocation(project: project).prepare();

    final Packages packages = Packages.load();
    final List<Package> active = packages.active;

    final List<String> profiles = <String>[...Packages.profilesOf(active), if (withWorker) workerProfile]..sort();

    final SizingRules rules = SizingRules(
      hardware,
      Capacity.load(mounted: active, profiles: profiles.toSet()),
      cpuCap: cpuCap,
    );
    final Map<String, String> values = <String, String>{...rules.resolve(), ..._identity()};

    globals.logger.printTrace('[sizing] hardware $hardware');
    if (targetName != null) {
      globals.logger.printStatus('target ${targetName!}: $hardware${cpuCap ? ', cores capped' : ''}');
    }
    globals.logger.printStatus(
      'api x${rules.apiReplicas}, rest x${rules.restReplicas}, storage x${rules.storageReplicas}, '
      'db ${values['db_mem_limit']} (shared_buffers ${values['db_shared_buffers']}), '
      'pool ${values['rest_db_pool']}/instance',
    );

    if (hardware.memoryGb < 4 || hardware.cores < 2) {
      globals.logger.printWarning('very small machine ($hardware), the stack may not start.');
    }

    _reportSelection(packages, active, profiles);

    final SocleOps socle = SocleOps();
    final List<File> rendered = <File>[
      for (final String name in mergedTemplates)
        await _renderTemplate(name, values, target, <YamlFragment>[
          ...socle.fragmentsFor(name),
          ...packages.fragmentsFor(name, active),
        ]),
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

    final StackLocation stack = StackLocation(project: project);
    await GatewayRender(project: project).render(stack.services.childDirectory('gateway'), values, active);
    await ProxyRender(project: project).render(stack.services.childDirectory('proxy'), values);
    await _renderServiceAssets(stack.services, values);
    await _renderEnvironments(stack.env, values, active);

    return ComposeDocuments(
      files: rendered,
      profiles: profiles,
      projectDirectory: project.directory.absolute.path,
      projectName: project.manifest.name.toSnakeCase(),
    );
  }

  /// The values that name the project rather than size it.
  Map<String, String> _identity() {
    final String name = project.manifest.name;

    return <String, String>{
      'app_name': name,
      'app_name_snake': name.toSnakeCase(),
      'sdk_root': './${p.basename(project.sdk.path)}',
      'alchemy_dir': p.basename(project.generated.path),
      // Absolute, and pointing at the cache. Left relative, Compose resolves a
      // mount against the project root, the daemon creates a directory where
      // the file should be, and the container dies on a parse error three
      // layers from the cause.
      'stack_env': StackLocation(project: project).env.absolute.path,
      for (final String service in SocleOps().serviceNames)
        'service_$service': StackLocation(project: project).services.childDirectory(service).absolute.path,
      'project_db_init': _projectDatabaseInit(StackLocation(project: project).services).absolute.path,
      'worker_endpoint': withWorker ? workerEndpoint : '',
      'api_url': project.manifest.apiUrl,
      'node_key_variables': nodeKeyVariables(project),
    };
  }

  /// The directory the database reads the project's own SQL from.
  ///
  /// `db/init` under the project when it ships SQL, and an empty directory of the
  /// stack otherwise. Never a path that is missing: a bind whose source is absent
  /// makes the daemon create it, and a project with no SQL would find an empty
  /// `db/init` appear at its root, which the node check then reports as a
  /// directory nothing declares.
  Directory _projectDatabaseInit(Directory services) {
    final Directory declared = project.directory.childDirectory('db').childDirectory('init');
    if (declared.existsSync()) {
      return declared;
    }

    return services.childDirectory(databaseServiceName).childDirectory('project-init')..createSync(recursive: true);
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

  /// Renders every file a service mounts, under the stack rather than the checkout.
  ///
  /// A container that read its configuration from the framework checkout would
  /// depend on which checkout happens to sit beside the project, and two
  /// projects sharing one would share it.
  Future<void> _renderServiceAssets(Directory target, Map<String, String> values) async {
    final SocleOps socle = SocleOps();

    for (final Directory service in socle.serviceDirectories) {
      final Directory into = target.childDirectory(p.basename(service.path));
      for (final File asset in socle.assetsOf(service)) {
        final String name = p.basename(asset.path).replaceAll(kTemplateSuffix, '');
        // The gateway document and the proxy configuration carry blocks built
        // from the nodes a project declares, so they have a renderer of their
        // own and are written by it, not here.
        if (name == gatewayFileName || name == proxyFileName) continue;
        if (!into.existsSync()) into.createSync(recursive: true);

        await into.childFile(name).writeAsString(renderTemplate(name, await asset.readAsString(), values));
      }
    }
  }

  /// Writes the environment files a service reads, one per audience.
  ///
  /// The socle declares an audience and every mounted package adds to it, by the
  /// same merge-by-name rule the compose fragments follow. A package the project
  /// did not mount contributes nothing, and no service lists it.
  Future<void> _renderEnvironments(Directory target, Map<String, String> values, List<Package> active) async {
    final Map<String, String> merged = <String, String>{...SocleOps().environments};

    for (final String audience in merged.keys.toList()) {
      for (final Package package in active) {
        for (final File file in package.fragments(audience)) {
          merged[audience] = '${merged[audience]}${file.readAsStringSync()}';
        }
      }
    }

    if (!target.existsSync()) target.createSync(recursive: true);
    for (final MapEntry<String, String> audience in merged.entries) {
      await target.childFile(audience.key).writeAsString(renderTemplate(audience.key, audience.value, values));
    }
  }

  /// Merges the socle's and the packages' slices of [name] onto the stack base.
  ///
  /// Every merged document is built on the same base, which carries the project
  /// name and nothing else: the socle declares its services the way a package
  /// declares its own, so no document has a body of its own to start from.
  Future<File> _renderTemplate(
    String name,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments,
  ) async {
    final File source = globals.templatePaths
        .directoryInPackage(kOpsTemplatesDirectoryName, globals.fs)
        .childFile('$stackTemplate$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No stack template at ${source.path}');
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
