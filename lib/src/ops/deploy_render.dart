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

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/forge/deploy/declared_deploy.dart';
import 'package:scribe_tools/src/forge/deploy/deploy_bridge_process.dart';
import 'package:scribe_tools/src/forge/deploy/emit_deploy.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/package/deploy.dart';
import 'package:scribe_tools/src/package/layout.dart';
import 'package:scribe_tools/src/package/manifest.dart';
import 'package:scribe_tools/src/package/resolution.dart';
import 'package:scribe_tools/src/package/sdk.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/runtime/js_runtime.dart';

/// Where a rendered package's `deploy/` lands, under the project's own generated directory —
/// never under the package itself, and never committed.
Directory _shadowRootOf(Project project, String packageName) =>
    project.generated.directory.childDirectory('deploy-render').childDirectory(packageName);

/// [active], with every package that carries `deploy/deploy.ts` replaced by a package whose
/// `directory` points at a freshly rendered, throwaway copy of `deploy/`.
///
/// A package with no `deploy/deploy.ts` is returned unchanged: `Capacity.load`, `Resources.load`,
/// `GatewayRender.render`, `Settings.read` and `Package.fragments` all read a plain `File`, never
/// `deploy.ts` itself, so a package they were never taught about needs no path of its own here —
/// swapping in a `Package` whose `directory` already holds what they expect is enough to reach
/// every one of them without changing any of them.
///
/// The swap is rebuilt whole on every call, the same as `db/init/00_schema.sql` already was: no
/// call here reads what a previous call wrote, so there is nothing to reconcile.
Future<List<Package>> resolveDeployPackages(List<Package> active, {required Project project}) async {
  final List<Package> resolved = <Package>[];

  for (final Package package in active) {
    final File declaration = package.directory.childDirectory(kDeployDirectory).childFile(kDeployDeclarationFile);
    if (!declaration.existsSync()) {
      resolved.add(package);
      continue;
    }

    resolved.add(await _renderShadow(package, declaration, project));
  }

  return resolved;
}

/// Renders [package]'s `deploy.ts` and answers a package whose `directory` holds the result.
Future<Package> _renderShadow(Package package, File declaration, Project project) async {
  final Sdk sdk = findSdk(from: project.sdk.path);
  final Resolution resolution = resolve(package.directory.path, sdk);

  final File manifestFile = package.directory.childFile(kManifestFile);
  final Manifest manifest = Manifest.parse(manifestFile.readAsStringSync(), manifestFile.path);
  final JsRuntime runtime = JsRuntime.named(manifest.runtime);

  final Directory shadow = _shadowRootOf(project, package.name);
  if (shadow.existsSync()) shadow.deleteSync(recursive: true);
  final Directory shadowDeploy = shadow.childDirectory(kDeployDirectory);

  _copyHandWrittenSql(package.directory, shadowDeploy);

  final DeclaredDeploy deploy = await runDeployBridge(source: declaration, resolution: resolution, runtime: runtime);
  final List<EmittedDeployFile> files = emitDeploy(
    packageName: manifest.name,
    deploy: deploy,
    handWrittenInit: _hasHandWrittenInit(package.directory),
    dbMountRoot: shadowDeploy.childDirectory(kDatabaseDirectory).path,
  );

  for (final EmittedDeployFile file in files) {
    final File target = globals.fs.file(p.join(shadowDeploy.path, p.joinAll(p.posix.split(file.path))));
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(file.content);
  }

  return Package(name: package.name, directory: shadow);
}

/// Copies a package's own `db/init/` and `db/migrations/`, written by hand, into [shadowDeploy].
///
/// `emitDeploy`'s own output lands in the same two directories right after this runs, so a package
/// that hand-writes its SQL — one with no `schema/`, `storage` today — keeps it, and a package
/// whose `deploy.ts` also declares `db.init`/`db.migrations` gets both: nothing here is exclusive
/// with what the bridge is about to add.
void _copyHandWrittenSql(Directory packageDirectory, Directory shadowDeploy) {
  for (final String moment in <String>['init', 'migrations', 'provisioning']) {
    final Directory source = packageDirectory
        .childDirectory(kDeployDirectory)
        .childDirectory(kDatabaseDirectory)
        .childDirectory(moment);
    if (!source.existsSync()) continue;

    final Directory destination = shadowDeploy.childDirectory(kDatabaseDirectory).childDirectory(moment);
    for (final FileSystemEntity entity in source.listSync(recursive: true)) {
      if (entity is! File) continue;
      final String relative = p.relative(entity.path, from: source.path);
      final File copy = destination.childFile(relative);
      copy.parent.createSync(recursive: true);
      copy.writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}

/// Whether [packageDirectory]'s `deploy/db/init/` already carries a file `emitDeploy` never wrote:
/// a `.gitkeep` and [kGeneratedSchemaFile] are the only two names its own reach ever produces
/// there, so anything else is SQL a package without a `schema/` wrote by hand.
bool _hasHandWrittenInit(Directory packageDirectory) {
  final Directory init = packageDirectory
      .childDirectory(kDeployDirectory)
      .childDirectory(kDatabaseDirectory)
      .childDirectory('init');
  if (!init.existsSync()) return false;

  return init
      .listSync(followLinks: false)
      .whereType<File>()
      .any((File file) => !<String>['.gitkeep', kGeneratedSchemaFile].contains(p.basename(file.path)));
}
