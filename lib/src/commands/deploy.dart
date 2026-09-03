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

import 'dart:convert';

import 'package:change_case/change_case.dart';
import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as pathlib;
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/base/template.dart';
import 'package:scribe_tools/src/commands/gen/code/generate.dart';
import 'package:scribe_tools/src/commands/gen/routes/routes_command.dart';
import 'package:scribe_tools/src/deploy/configuration_audit.dart';
import 'package:scribe_tools/src/deploy/drivers/ssh.dart';
import 'package:scribe_tools/src/deploy/plan.dart';
import 'package:scribe_tools/src/deploy/tofu.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/configuration.dart';
import 'package:scribe_tools/src/ops/hardware.dart';
import 'package:scribe_tools/src/ops/resources.dart';
import 'package:scribe_tools/src/ops/sizing.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/runner/scribe_command.dart';
import 'package:scribe_tools/src/stack/compose.dart';
import 'package:scribe_tools/src/stack/router.dart';
import 'package:scribe_tools/src/stack/stack_location.dart';
import 'package:scribe_tools/src/stack/stack_manifest.dart';
import 'package:scribe_tools/src/tools.dart';

/// One param as a `.tf.json` recipe receives it, quoted by the recipe and not by this.
///
/// A list or a map is encoded rather than printed, because a recipe holding
/// `"subnets": {{subnet_ids}}` is read back as JSON: Dart printing a list gives
/// `[a, b]`, which no parser accepts. A string keeps only what [jsonEncode]
/// puts between its own quotes: the recipe already supplies the quotes around
/// the placeholder, so passing the string through unescaped would let a `"` a
/// project wrote in `params:` close that string early and inject whatever
/// follows as new JSON, and encoding the whole value would nest a second pair
/// of quotes inside the recipe's.
String paramForRecipe(Object? value) {
  if (value is! String) return jsonEncode(value);

  final String encoded = jsonEncode(value);
  return encoded.substring(1, encoded.length - 1);
}

/// Deploys this project onto one of the targets it declares.
///
/// It is not `run --target`, and that is deliberate: `run` is the local loop,
/// it talks to the daemon at hand, and `shutdown` undoes exactly what it did.
/// A deployment creates things that cost money and that stopping a stack does
/// not undo, so it carries a verb of its own.
class DeployCommand extends ScribeCommand {
  /// Declares the target it deploys onto and the three flags around it.
  DeployCommand() {
    argParser
      ..addOption('target', abbr: 't', help: 'The target of configuration/main.yaml this deploys onto.')
      ..addFlag('plan', negatable: false, help: 'Say everything it would do, and write nothing.')
      ..addFlag('yes', abbr: 'y', negatable: false, help: 'Do not ask before creating anything.')
      ..addFlag(
        'worker',
        abbr: 'w',
        negatable: false,
        help: 'Run the project code in a container of its own, and point the API at it.',
      );
  }

  @override
  String get name => 'deploy';

  @override
  String get description => 'Deploy this project onto one of the targets it declares.';

  @override
  bool get requiresCompleteManifest => true;

  @override
  List<ExternalTool> get requiredTools => const <ExternalTool>[ToolCatalog.docker];

  @override
  Future<ScribeCommandResult> runCommand() async {
    final String? targetName = stringArg('target');
    if (targetName == null) {
      throwToolExit(_noTarget());
    }

    if (refusalForAnUnforgedProject(project) case final String refusal) {
      throwToolExit(refusal);
    }

    await generateProjectCode();
    await generateRoutes();

    final Target target = ProjectConfiguration.load(project: project).target(targetName);
    final bool remote = target.host.isNotEmpty && target.registry.isNotEmpty;

    // The host is asked where the stack will sit before anything is rendered:
    // every bind mount inside the documents is absolute, so a path that is right
    // here and wrong there is a container that dies three layers from the cause.
    String? root;
    String platform = '';
    if (remote && !boolArg('plan')) {
      globals.tools
        ..require(ToolCatalog.ssh, reason: 'a ${target.kind.name} target is reached over it')
        ..require(ToolCatalog.rsync, reason: 'the stack is carried to ${target.host} with it');

      root = await _rootOn(target);
      if (root == null) return const ScribeCommandResult.fail();

      platform = target.platform.isNotEmpty ? target.platform : await _platformOf(target);
      if (platform.isEmpty) return const ScribeCommandResult.fail();
      globals.logger.printStatus('${target.host} runs $platform');
    }

    final Hardware hardware = await Hardware.detect();

    Future<ComposeDocuments> renderFor(
      String? seenAt, {
      Map<String, String> images = const <String, String>{},
      Map<String, Map<String, String>> resourceOutputs = const <String, Map<String, String>>{},
    }) => ComposeRender(
      project: project,
      withWorker: boolArg('worker'),
      targetName: targetName,
      stackRoot: seenAt,
      platform: platform,
      images: images,
      resourceOutputs: resourceOutputs,
    ).render(hardware);

    // Rendered once before anything is created, with no resource's outputs
    // known yet. A class comes from where a target places a resource, never
    // from what it produces, so the plan this builds is accurate; only the
    // outputs a provisioned resource would show are still blank. Nothing here
    // is started or published, and nothing here costs anything: it exists to
    // be reported and judged against the blockers below before a single
    // dollar is spent.
    final ComposeDocuments planned = await renderFor(null);
    final DeploymentPlan plan = DeploymentPlan(
      target: target,
      resources: planned.resources,
      services: planned.profiles,
    );
    _report(plan);

    if (plan.blockers.isNotEmpty) {
      for (final String blocker in plan.blockers) {
        globals.logger.printError(blocker);
      }

      return const ScribeCommandResult.fail();
    }

    if (boolArg('plan')) {
      if (await _provision(target, dryRun: true) == null) return const ScribeCommandResult.fail();
      globals.logger.printStatus('Plan only: nothing was created and nothing was started.');
      return const ScribeCommandResult.success();
    }

    if (plan.createsAnything && !boolArg('yes')) {
      globals.logger.printStatus('Nothing was created. Pass --yes to create what is listed above.');
      return const ScribeCommandResult.success();
    }

    final Map<String, Map<String, String>>? made = await _provision(target, dryRun: false);
    if (made == null) return const ScribeCommandResult.fail();

    // Rendered again for this machine, now that every resource has real
    // outputs: the images are built and pushed here, and `docker compose`
    // reads the whole document to do it, mounts included. A path that names
    // the host is a path this machine does not have.
    final ComposeDocuments documents = await renderFor(null, resourceOutputs: made);

    if (plan.target.registry.isNotEmpty) {
      if (await _publish(documents) case final ScribeCommandResult refusal) {
        return refusal;
      }
    }

    if (!remote) return _start(plan, documents);

    // Rendered a third time, for the host this time: what it mounts is its
    // own, and the documents are two readers rather than one document
    // travelling. It is pinned to the digests the push returned, so the host
    // pulls what it lacks and can only run what was just built.
    return _startThere(plan, await renderFor(root, images: await _digestsOf(target), resourceOutputs: made), root!);
  }

  /// Creates the resources whose recipe is configuration, and returns what they made.
  ///
  /// A recipe written as `.tf.json` produces its outputs rather than holding
  /// them: a password a provider generates does not exist before the apply. The
  /// state of each one lives under the project and never in the stack cache,
  /// which is emptied on every render.
  Future<Map<String, Map<String, String>>?> _provision(Target target, {required bool dryRun}) async {
    final ProjectConfiguration configuration = ProjectConfiguration.load(project: project);
    final List<Package> mounted = Packages.load().active;
    final List<Directory> roots = Resources.recipeRoots(project: project, mounted: mounted);
    final Map<String, Map<String, String>> made = <String, Map<String, String>>{};

    for (final Resource resource in Resources.declared(mounted: mounted)) {
      final Placement placement = configuration.placementOf(target.name, resource.name);
      if (placement.isContainer || placement.isExternal) continue;

      final File? recipe = Resources.recipeFor(roots, resource.type, placement.recipeName);
      if (recipe == null || !recipe.path.contains('.tf.json')) continue;

      globals.tools.require(
        ToolCatalog.tofu,
        reason: '${resource.name} is placed on "${placement.recipeName}", which is configuration it applies',
      );

      final Tofu tofu = Tofu(_stateOf(target, resource))
        ..write(
          jsonDecode(renderTemplate(recipe.path, recipe.readAsStringSync(), _paramsOf(resource, placement)))
              as Map<String, Object?>,
        );

      globals.logger.printStatus('${resource.name}: ${placement.recipeName}');
      if (!await tofu.init()) return null;

      if (dryRun) {
        final String? plan = await tofu.plan();
        if (plan == null) return null;
        globals.logger.printStatus(plan.trim());
        continue;
      }

      if (!await tofu.apply()) return null;

      final Map<String, String>? outputs = await tofu.outputs();
      if (outputs == null) return null;
      made[resource.name] = outputs;
    }

    return made;
  }

  /// Where the state of one provisioned resource lives.
  ///
  /// Under the project and not in the stack cache: the cache is emptied on every
  /// render, and losing a state is losing the trace of a database that exists
  /// and that bills.
  Directory _stateOf(Target target, Resource resource) => project.directory
      .childDirectory('.scribe')
      .childDirectory('state')
      .childDirectory(target.name)
      .childDirectory(resource.name);

  /// What a recipe is given, as the strings a template is rendered with.
  /// What a recipe of [resource] may reference, its own name included.
  ///
  /// The name comes for free rather than being written in `params:`, because a
  /// project that has already named its resource under `requires:` would be
  /// naming it a second time to say the same thing. A `params:` entry called
  /// `name` still wins, for a provider that limits what an identifier may hold.
  Map<String, String> _paramsOf(Resource resource, Placement placement) => <String, String>{
    'name': paramForRecipe(resource.name),
    for (final MapEntry<String, Object?> entry in placement.params.entries) entry.key: paramForRecipe(entry.value),
  };

  /// Where the stack will sit on the host, null when the host cannot be reached.
  Future<String?> _rootOn(Target target) async {
    final String? home = await RemoteHost(target.host).home();
    if (home == null) {
      globals.logger.printError('${target.host} did not answer, so nothing was rendered for it.');

      return null;
    }

    return pathlib.posix.join(home, '.scribe_cache', 'stacks', StackLocation(project: project).fingerprint);
  }

  /// The exact reference of each built image, read back from the daemon.
  ///
  /// A tag can be moved and a digest cannot, so what the host is told to run is
  /// what was pushed a second earlier and nothing else. A service the registry
  /// has no digest for is left on its tag, which is the case before a first push.
  Future<Map<String, String>> _digestsOf(Target target) async {
    final String name = project.manifest.name.toSnakeCase();
    final Map<String, String> pinned = <String, String>{};

    for (final String service in <String>['api', 'functions', 'db', 'rest']) {
      final String reference = '${target.registry}/$name-$service:${target.tag}';
      final ProcessOutcome outcome = await globals.processRunner.observe(<String>[
        'docker',
        'image',
        'inspect',
        reference,
        '--format',
        '{{index .RepoDigests 0}}',
      ]);
      if (!outcome.succeeded) continue;

      final String digest = outcome.stdout.trim();
      if (digest.contains('@sha256:')) pinned[service] = digest;
    }

    return pinned;
  }

  /// The platform the host builds for, empty when it cannot be read.
  ///
  /// A workstation and a server are rarely the same architecture, and an image
  /// built for the wrong one is refused at the pull with a message about a
  /// manifest that says nothing about the cause.
  Future<String> _platformOf(Target target) async {
    final ProcessOutcome outcome = await globals.processRunner.observe(
      commandArgv(Ssh.destination(target.host).remoteCommand('uname -m')),
    );
    if (!outcome.succeeded) {
      globals.logger.printError('${target.host} did not say what it runs on.');

      return '';
    }

    return switch (outcome.stdout.trim()) {
      'x86_64' || 'amd64' => 'linux/amd64',
      'aarch64' || 'arm64' => 'linux/arm64',
      final String other => _unknownArchitecture(target, other),
    };
  }

  String _unknownArchitecture(Target target, String read) {
    globals.logger.printError(
      '${target.host} says it runs on "$read", which is not an architecture images are built for.\n'
      'Write targets.${target.name}.platform to name one, such as linux/amd64.',
    );

    return '';
  }

  /// Ships the stack to the host and starts it there.
  ///
  /// Everything a container reads is inside the stack when a target bakes, so
  /// one directory is the whole deployment: there is nothing else to copy and
  /// nothing on the host to keep in step by hand.
  Future<ScribeCommandResult> _startThere(DeploymentPlan plan, ComposeDocuments documents, String root) async {
    final RemoteHost host = RemoteHost(plan.target.host);
    final StackLocation location = StackLocation(project: project);

    globals.logger.printStatus('Shipping the stack to ${plan.target.host}...');
    if (!await host.ship(location.directory, root)) {
      return const ScribeCommandResult.fail();
    }

    final List<String> documentsThere = <String>[
      for (final File file in documents.files) pathlib.posix.join(root, pathlib.basename(file.path)),
    ];

    globals.logger.printStatus('Starting it there...');
    final int status = await host.compose(
      // Never `--build`: a host that cannot pull an image has to say so, and
      // not fall back to building from a context that only this machine has.
      // `missing` rather than `always` because the references are digests: what
      // the host already holds under that name is what was built.
      <String>['up', '-d', '--remove-orphans', '--no-build', '--pull', 'missing'],
      root: root,
      projectName: documents.projectName,
      documents: documentsThere,
    );
    if (status != 0) return const ScribeCommandResult.fail();

    // The same wait a local target gets: `up -d` returns as soon as the
    // containers exist, and a host that is still laying its database down has
    // not deployed anything yet.
    final bool settled = await StackHealth(
      () => host.composeSays(
        <String>['ps', '--format', 'json', '--all'],
        root: root,
        projectName: documents.projectName,
        documents: documentsThere,
      ),
    ).settles();
    if (!settled) return const ScribeCommandResult.fail();

    globals.logger.printStatus('ready  ${plan.target.domain}');

    return const ScribeCommandResult.success();
  }

  /// Builds the images and puts them in the registry, or says why it could not.
  ///
  /// It runs before the blockers are read, because the images are what a remote
  /// target is missing, and a project has to be able to publish them before the
  /// leg that pulls them exists.
  Future<ScribeCommandResult?> _publish(ComposeDocuments documents) async {
    final StackManifest manifest = StackManifest(
      projectDirectory: documents.projectDirectory,
      projectName: documents.projectName,
      files: <String>[for (final File file in documents.files) file.absolute.path],
      profiles: documents.profiles,
    );
    final Compose compose = Compose(manifest);

    globals.logger.printStatus('Building the images this deployment carries...');
    if (await compose.build() != 0) return const ScribeCommandResult.fail();

    globals.logger.printStatus('Pushing them to the registry...');
    if (await compose.push() != 0) return const ScribeCommandResult.fail();

    return null;
  }

  String _noTarget() {
    final List<Target> targets = ProjectConfiguration.load(project: project).targets;

    return <String>[
      'A deployment needs a target, which says where it goes.',
      if (targets.isEmpty)
        'This project declares none. `scribe forge` writes configuration/main.yaml with one.'
      else
        'This project declares: ${targets.map((Target t) => t.name).join(', ')}.',
      '',
      'scribe deploy --target ${targets.isEmpty ? '<name>' : targets.first.name}',
    ].join('\n');
  }

  void _report(DeploymentPlan plan) {
    globals.logger.printStatus('');
    globals.logger.printStatus(
      '  ${plan.target.name}  ${plan.target.kind.name}'
      '${plan.target.host.isEmpty ? '' : '  ${plan.target.host}'}',
    );
    globals.logger.printStatus('');

    for (final ResolvedResource resource in plan.resources.resolved) {
      globals.logger.printStatus('  ${resource.resource.name.padRight(12)}${resource.className}');
    }

    globals.logger.printStatus('');
    globals.logger.printStatus(
      '${plan.inContainers.length} in containers, ${plan.alreadyThere.length} already there, '
      '${plan.provisioned.length} to create',
    );
  }

  Future<ScribeCommandResult> _start(DeploymentPlan plan, ComposeDocuments documents) async {
    final StackLocation location = StackLocation(project: project);
    final StackManifest manifest = StackManifest(
      projectDirectory: documents.projectDirectory,
      projectName: documents.projectName,
      files: <String>[for (final File file in documents.files) file.absolute.path],
      profiles: documents.profiles,
    )..write(location.manifest);

    final Compose compose = Compose(manifest);
    if (!await compose.reads()) {
      throwToolExit(
        'The assembled project does not hold together. It is left in ${location.directory.path} to be read.',
      );
    }

    const Router router = Router();
    if (!await router.ensureUp()) {
      throwToolExit('The router of this machine did not start, so nothing would be reachable.');
    }

    if (await compose.upUntilHealthy() != 0) return const ScribeCommandResult.fail();

    await router.attach('${manifest.projectName}_edge');
    globals.logger.printStatus('ready  ${plan.target.domain.isEmpty ? documents.hostnames.first : plan.target.domain}');

    return const ScribeCommandResult.success();
  }
}
