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
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/prune.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/deploy/settings.dart';
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
import 'package:scribe_tools/src/scribe_manifest.dart';
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
    required this.hostnames,
    required this.files,
    required this.kind,
    required this.profiles,
    required this.projectDirectory,
    required this.projectName,
    required this.resources,
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

  /// What this render was made for, which decides how the stack is reached.
  final TargetKind kind;

  /// Every resource of this stack, each answered by the recipe its target names.
  ///
  /// It travels with the documents because a plan has to say what a deployment
  /// creates, and only the render knows: it is the one that read the targets,
  /// the declarations and the recipes.
  final Resources resources;

  /// Every hostname the router will answer this stack on.
  ///
  /// The project's own name under `.scribe.localhost`, so a machine running ten
  /// projects reaches each without naming a port, and the domain the manifest
  /// declares, which is the one a deployment answers on.
  final List<String> hostnames;
}

/// The compose documents of a project, rendered from the templates the tool ships.
///
/// Neither the tool's own tree nor the framework's is written to: the templates
/// and the package fragments are fixed, and everything this produces lands under
/// the project's generated directory.
class ComposeRender {
  /// Renders [project], the one the command is running in when none is named.
  ComposeRender({
    Project? project,
    this.withWorker = false,
    this.targetName,
    this.stackRoot,
    this.platform = '',
    this.images = const <String, String>{},
    this.resourceOutputs = const <String, Map<String, String>>{},
  }) : project = project ?? globals.project;

  /// The exact reference each built service is to run, by service name.
  ///
  /// A tag can be moved, so a host told to run one has no way of knowing which
  /// build it got. After a push the registry answers with a digest, and pinning
  /// the document to it makes the reference say what the content is: the host
  /// then pulls only what it does not have, and can only run what was built.
  final Map<String, String> images;

  /// The architecture the images are built for, empty for this machine's own.
  final String platform;

  /// What a recipe already produced, by resource name.
  ///
  /// A resource a provider created answers with what the apply returned, and no
  /// file can hold that: the password did not exist before it ran.
  final Map<String, Map<String, String>> resourceOutputs;

  /// The absolute path the containers will see the stack at, null when it is here.
  ///
  /// A deployment ships the stack to a host and starts it there, so every bind
  /// mount inside the documents has to name the path on that host and not the
  /// one in this cache. What is built rather than mounted keeps its own path,
  /// because building happens where the sources are.
  final String? stackRoot;

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
    final Target? deployingTo = targetName == null ? null : _configuration.target(targetName!);
    final Hardware hardware = (deployingTo?.machine ?? detected).sharing(deployingTo?.share ?? 1);
    final bool cpuCap = deployingTo?.cpuCap ?? false;
    final TargetKind kind = deployingTo?.kind ?? TargetKind.machine;

    // Outside the project, and emptied first: an overlay whose package the
    // project has since dropped would otherwise survive, and the only practical
    // way to list the documents again is a glob, so the dead one would be
    // mounted with the live ones.
    final Directory target = StackLocation(project: project).prepare();

    final Packages packages = Packages.load();
    final List<Package> active = packages.active;

    final List<String> profiles = <String>[...Packages.profilesOf(active), if (withWorker) workerProfile]..sort();

    final Resources resources = Resources.load(mounted: active, placement: _placement, outputs: resourceOutputs);
    final Set<String> gone = resources.suppressedServices;

    final SizingRules rules = SizingRules(
      hardware,
      Capacity.load(mounted: active, profiles: profiles.toSet(), without: gone),
      cpuCap: cpuCap,
    );
    final Map<String, String> values = <String, String>{
      ...rules.resolve(),
      ...resources.values,
      ..._settings(active),
      ..._identity(),
      'proxy_ports': _proxyPorts(kind),
      'tls_resolver': _tlsResolver(),
    };

    globals.logger.printTrace('[sizing] hardware $hardware');
    if (targetName != null) {
      globals.logger.printStatus('target ${targetName!}: $hardware${cpuCap ? ', cores capped' : ''}');
    }
    globals.logger.printStatus(
      <String>[
        'api x${rules.apiReplicas}, rest x${rules.restReplicas}, storage x${rules.storageReplicas}',
        if (values['db_mem_limit'] case final String limit) 'db $limit (shared_buffers ${values['db_shared_buffers']})',
        if (values['rest_db_pool'] case final String pool) 'pool $pool/instance',
      ].join(', '),
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
        ], gone: gone),
    ];

    // One file per overlay, never one per package: two overlays that patch the
    // same socle service would produce two identical keys in one document, and
    // it is `docker compose` that knows how to combine them.
    int position = 1;
    for (final Package package in active) {
      for (final YamlFragment overlay in package.fragmentsFor(overlayTemplate)) {
        rendered.insert(
          position++,
          await _write(overlayFileName(overlay.label), overlayBase, values, target, <YamlFragment>[
            overlay,
          ], gone: gone),
        );
      }
    }

    final StackLocation stack = StackLocation(project: project);
    await _carrySecrets(stack.directory);
    _carryFrameworkSql(stack.directory);
    await GatewayRender(project: project).render(stack.services.childDirectory('gateway'), values, active);
    await ProxyRender(project: project).render(stack.services.childDirectory('proxy'), values);
    await _renderServiceAssets(stack.services, values);
    await _renderEnvironments(stack.env, values, active);

    return ComposeDocuments(
      resources: resources,
      files: rendered,
      profiles: profiles,
      projectDirectory: project.directory.absolute.path,
      projectName: project.manifest.name.toSnakeCase(),
      hostnames: _hostnames(),
      kind: kind,
    );
  }

  /// What each mounted package was configured with, by the key a fragment reads.
  ///
  /// A package declares what it lets a project decide, `forge` writes those
  /// defaults into `configuration/<package>.yaml`, and this is where what the
  /// project wrote reaches the container. Without it a setting is a file
  /// somebody edits and nothing reads.
  Map<String, String> _settings(List<Package> mounted) => <String, String>{
    for (final Package package in mounted)
      ...Settings.read(
        package.directory.childFile(configurationFileName),
      ).valuesFor(package.name, _configuration.settingsOf(package.name)),
  };

  /// Where a resource goes on the target being rendered for.
  ///
  /// A render with no target is a render for the machine at hand, where nothing
  /// is placed anywhere else: a workstation is the one case that cannot have
  /// been described by a target block.
  Placement _placement(String resource) =>
      targetName == null ? Placement.inContainer : _configuration.placementOf(targetName!, resource);

  /// How and where this project runs, read once per render.
  late final ProjectConfiguration _configuration = ProjectConfiguration.load(project: project);

  /// The domain this render answers on, the target's when it names one.
  ///
  /// A domain belongs to the target because it is the value that differs between
  /// a workstation and a deployment, and a project holding a single one could
  /// never have two.
  String get _apiUrl {
    final String declared = targetName == null ? '' : _configuration.target(targetName!).domain;

    return declared.isEmpty ? project.manifest.apiUrl : declared;
  }

  /// Every hostname this stack claims, in the order the labels write them.
  List<String> _hostnames() => <String>[
    '${project.manifest.name.toSnakeCase()}.scribe.localhost',
    Uri.parse(_apiUrl).host,
  ].where((String host) => host.isNotEmpty).toList();

  /// The values that name the project rather than size it.
  /// The certificate resolver the router uses for this project, empty when none.
  ///
  /// A resolver means a real certificate, and a real certificate means a
  /// challenge the authority answers by reaching the name from outside. That
  /// works for the domain the manifest declares and cannot work for
  /// `<name>.scribe.localhost`, which resolves nowhere but on this machine.
  ///
  /// Asking for one anyway would not merely fail: the authority rate-limits a
  /// name that keeps failing, and the router would carry a pending order for
  /// every project on the host. Empty leaves the router on the certificate it
  /// signs itself, which is what a machine with no public name wants.
  String _tlsResolver() {
    final String host = Uri.parse(_apiUrl).host;

    return host.isEmpty || host.endsWith('.localhost') ? '' : 'public';
  }

  /// The `ports:` the proxy publishes, empty everywhere but on a workstation.
  ///
  /// A `machine` target puts one router in front of every project and none of
  /// them holds a host port, which is what lets ten of them run at once. A
  /// workstation has no router and no hostname that resolves, so the stack has
  /// to be reachable some other way, and the only one that does not collide with
  /// the next project is a port the daemon picks.
  ///
  /// `scribe run` reads the port back from the container and prints it, because
  /// a port nobody can name is a stack nobody can call.
  String _proxyPorts(TargetKind kind) => kind == TargetKind.dev ? '\n    ports: ["80"]' : '';

  Map<String, String> _identity() {
    final String name = project.manifest.name;

    return <String, String>{
      'app_name': name,
      'app_name_snake': name.toSnakeCase(),
      'sdk_root': _sdkSeenByContainers(),
      'alchemy_dir': p.basename(project.generated.path),
      // Absolute, and pointing at the cache. Left relative, Compose resolves a
      // mount against the project root, the daemon creates a directory where
      // the file should be, and the container dies on a parse error three
      // layers from the cause.
      'stack_env': _seenAt(StackLocation(project: project).env),
      for (final String service in SocleOps().serviceNames) ...<String, String>{
        // What a container mounts is a path on the host it runs on; what a build
        // reads is a path on the machine that builds, and those part company as
        // soon as a target names one.
        'service_$service': _seenAt(StackLocation(project: project).services.childDirectory(service)),
        'local_service_$service': StackLocation(project: project).services.childDirectory(service).absolute.path,
      },
      'dockerfile_api': StackLocation(
        project: project,
      ).services.childDirectory('api').childFile('Dockerfile').absolute.path,
      'dockerfile_functions': StackLocation(
        project: project,
      ).services.childDirectory('functions').childFile('Dockerfile').absolute.path,
      'project_db_init': _seenAt(_projectDatabaseDirectory(StackLocation(project: project).services, 'init')),
      'project_db_migrations': _seenAt(
        _projectDatabaseDirectory(StackLocation(project: project).services, 'migrations'),
      ),
      'worker_endpoint': withWorker ? workerEndpoint : '',
      'api_url': _apiUrl,
      'api_host': Uri.parse(_apiUrl).host,
      'node_key_variables': nodeKeyVariables(project),
      ..._images(),
    };
  }

  /// Whether the images carry the project rather than mount it.
  ///
  /// A host that is not this one cannot see `./lib`, so a target that names a
  /// registry gets images with the project inside them. A target that names
  /// none keeps the mounts, which is what makes a change to a route visible on
  /// a workstation without rebuilding anything.
  bool get _bakes => targetName != null && _configuration.target(targetName!).registry.isNotEmpty;

  /// What names the images, what they are built from, and what they mount.
  Map<String, String> _images() {
    final String prefix = targetName == null ? '' : _configuration.target(targetName!).registry;
    final String name = project.manifest.name.toSnakeCase();
    final String tag = prefix.isEmpty ? 'local' : (_configuration.target(targetName!).tag);
    final StackLocation stack = StackLocation(project: project);

    String image(String service) =>
        images[service] ?? (prefix.isEmpty ? '$name-$service:local' : '$prefix/$name-$service:$tag');

    return <String, String>{
      'image_api': image('api'),
      'image_worker': image('api'),
      'image_functions': image('functions'),
      'image_db': image('db'),
      'image_rest': image('rest'),
      'image_backup': image('backup'),
      'build_platform': platform.isEmpty ? '' : 'platforms: ["$platform"]',
      'build_context_api': _bakes
          ? project.directory.absolute.path
          : stack.services.childDirectory('api').absolute.path,
      'build_context_functions': _bakes
          ? project.directory.absolute.path
          : stack.services.childDirectory('functions').absolute.path,
      'source_mounts_api': _bakes
          ? ''
          : '      - "./${p.basename(project.sdk.path)}:/app/scribe:ro"\n'
                '      - "./${p.basename(project.generated.path)}/sdk/js:/app/${p.basename(project.generated.path)}/sdk/js:ro"\n'
                '      - "./lib:/app/lib:ro"\n',
      'source_mounts_functions': _bakes
          ? ''
          : '      - "./${p.basename(project.sdk.path)}/engine:/home/deno/functions:ro"\n'
                '      - "./${p.basename(project.generated.path)}/sdk/js:/home/deno/${p.basename(project.generated.path)}/sdk/js:ro"\n',
      'bake_project': _bakes ? _bakeInto('/app') : '',
      'bake_functions': _bakes ? _bakeFunctionsInto('/home/deno') : '',
    };
  }

  /// The lines that put the project inside an image, under [root].
  String _bakeInto(String root) {
    final String sdk = p.basename(project.sdk.path);
    final String derived = p.basename(project.generated.path);

    return 'WORKDIR $root\n'
        'COPY $sdk $root/scribe\n'
        'COPY $derived/sdk/js $root/$derived/sdk/js\n'
        'COPY lib $root/lib\n';
  }

  /// The same, for the edge runtime, which reads a different half of the tree.
  String _bakeFunctionsInto(String root) {
    final String sdk = p.basename(project.sdk.path);
    final String derived = p.basename(project.generated.path);

    return 'WORKDIR $root\n'
        'COPY $sdk/engine $root/functions\n'
        'COPY $derived/sdk/js $root/$derived/sdk/js\n';
  }

  /// Where a container finds the framework's own files, which is not the checkout.
  ///
  /// A package mounts its SQL from `{{sdk_root}}`, and on a host the checkout is
  /// not there: the mount would be a path the daemon creates as root, which is
  /// both an empty provisioning and a directory nobody can delete afterwards.
  /// What those mounts read is copied into the stack instead, and this names it.
  String _sdkSeenByContainers() => stackRoot == null ? './${p.basename(project.sdk.path)}' : '$stackRoot/sdk';

  /// Copies what a container mounts out of the framework into the stack.
  ///
  /// Only the SQL: the code is inside the images by the time a stack ships, and
  /// what is left mounted is what a package lays into a database.
  void _carryFrameworkSql(Directory into) {
    if (stackRoot == null) return;

    final Directory packages = project.sdk.directory.childDirectory('packages');
    if (!packages.existsSync()) return;

    for (final Directory package in packages.listSync().whereType<Directory>()) {
      final Directory db = package.childDirectory('db');
      if (!db.existsSync()) continue;

      _copyInto(
        db,
        into
            .childDirectory('sdk')
            .childDirectory('packages')
            .childDirectory(p.basename(package.path))
            .childDirectory('db'),
      );
    }
  }

  /// Copies every file under [from] into [to], directories included.
  void _copyInto(Directory from, Directory to) {
    to.createSync(recursive: true);

    for (final FileSystemEntity entity in from.listSync()) {
      if (entity is File) {
        to.childFile(p.basename(entity.path)).writeAsStringSync(entity.readAsStringSync());
        continue;
      }
      if (entity is Directory) _copyInto(entity, to.childDirectory(p.basename(entity.path)));
    }
  }

  /// Puts the project's `.env` beside the documents when the stack ships.
  ///
  /// Compose reads it from the project directory, and on a host that directory
  /// is the stack: without it every reference in the documents resolves to
  /// nothing, and the cluster refuses to initialise on an empty password.
  ///
  /// It is written for a host and never for here, because here the project's own
  /// directory is what Compose is pointed at and the file is already read.
  Future<void> _carrySecrets(Directory into) async {
    if (stackRoot == null) return;

    final File declared = project.directory.childFile('.env');
    if (!declared.existsSync()) return;

    final File carried = into.childFile('.env')..writeAsStringSync(declared.readAsStringSync());
    await globals.processRunner.run(<String>['chmod', '600', carried.path]);
  }

  /// Where a container will see [here], which is elsewhere when the stack ships.
  ///
  /// A path under the stack is rewritten against [stackRoot]; a path outside it,
  /// which only a mounting target has, is left alone because such a target never
  /// ships anywhere.
  String _seenAt(Directory here) {
    final String root = StackLocation(project: project).directory.absolute.path;
    final String path = here.absolute.path;
    if (stackRoot == null || !path.startsWith(root)) return path;

    return '$stackRoot${path.substring(root.length)}';
  }

  /// The directory a service reads the project's own `db/<name>` from.
  ///
  /// The project's directory when it ships one, and an empty directory of the
  /// stack otherwise. Never a path that is missing: a bind whose source is absent
  /// makes the daemon create it, so a project with no SQL used to find an empty
  /// `lib/db/` appear at its root, which the node check then reports as a
  /// directory nothing declares.
  Directory _projectDatabaseDirectory(Directory services, String name) {
    final Directory declared = project.directory.childDirectory('db').childDirectory(name);
    final Directory inStack = services.childDirectory(databaseServiceName).childDirectory('project-$name')
      ..createSync(recursive: true);

    // A target that bakes ships one directory and nothing else, so what the
    // project holds is copied in rather than mounted from where it sits.
    if (!declared.existsSync()) return inStack;
    if (!_bakes) return declared;

    for (final File file in declared.listSync().whereType<File>()) {
      inStack.childFile(p.basename(file.path)).writeAsStringSync(file.readAsStringSync());
    }

    return inStack;
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
    List<YamlFragment> fragments, {
    Set<String> gone = const <String>{},
  }) async {
    final File source = globals.templatePaths
        .directoryInPackage(kOpsTemplatesDirectoryName, globals.fs)
        .childFile('$stackTemplate$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No stack template at ${source.path}');
    }

    return _write(name, await source.readAsString(), values, target, fragments, gone: gone);
  }

  Future<File> _write(
    String name,
    String source,
    Map<String, String> values,
    Directory target,
    List<YamlFragment> fragments, {
    Set<String> gone = const <String>{},
  }) async {
    final File destination = target.childFile(name);
    await destination.writeAsString(
      renderTemplate(name, withoutServices(mergeYamlDocuments(source, fragments), gone), values),
    );

    return destination;
  }
}
