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
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:scribe_tools/src/ops/capacity.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/templates.dart';

/// The framework repository, checked out next to this one.
const String repository = '../scribe';

const FileSystem _fs = LocalFileSystem();

/// Where the mountable packages of the framework live.
///
/// One root and not two: the packages sit side by side under `packages/` at the
/// checkout root, which is the only place a render looks for them.
Directory get packagesRoot => _fs.directory(p.join(repository, 'packages'));

/// Where the socle's ops templates live, which is this package rather than the framework.
///
/// One directory per service, each holding its `capacity.yaml.tmpl` beside the
/// compose it weighs, so the two cannot come to describe different services.
Directory get socleOps => _fs.directory('templates/ops/services');

/// Every service directory of the socle, sorted so a run never depends on the file system.
List<Directory> get socleServices =>
    socleOps.listSync().whereType<Directory>().toList()..sort((Directory a, Directory b) => a.path.compareTo(b.path));

/// A `capacity.yaml` and the compose document its weights have to agree with.
///
/// Both sit in the same directory, since neither is read without the other.
class CapacitySource {
  const CapacitySource({required this.weights, required this.compose});

  /// The file holding the weights.
  final File weights;

  /// The compose document declaring the services those weights name.
  final File compose;
}

/// Every `capacity.yaml` of the framework and the compose it goes with.
///
/// The socle comes first, then one per package, keyed the way a mismatch has to
/// be reported for a reader to know which file to open.
Map<String, CapacitySource> capacitySources() => <String, CapacitySource>{
  for (final Directory service in socleServices)
    'services/${p.basename(service.path)}': CapacitySource(
      weights: service.childFile('$capacityFileName$kTemplateSuffix'),
      compose: service.childFile('docker-compose.yaml.tmpl'),
    ),
  for (final MapEntry<String, Directory> package in frameworkPackages().entries)
    for (final Directory subject in opsDirectories(package.value))
      _sourceKey(package.key, package.value, subject): CapacitySource(
        weights: subject.childFile(capacityFileName),
        compose: subject.childFile('docker-compose.yaml'),
      ),
};

/// The directories of [package] that may hold a `capacity.yaml`.
///
/// A package groups its ops by subject, so the weights of the cache sit in
/// `ops/valkery/` while a package that ships one container keeps them in `ops/`.
List<Directory> opsDirectories(Directory package) {
  final Directory ops = package.childDirectory('ops');
  if (!ops.existsSync()) return const <Directory>[];

  return <Directory>[if (ops.childFile(capacityFileName).existsSync()) ops, ...ops.listSync().whereType<Directory>()];
}

/// How a mismatch names the file to open.
String _sourceKey(String package, Directory root, Directory subject) =>
    subject.path == root.childDirectory('ops').path ? package : '$package/${p.basename(subject.path)}';

/// Every package of the framework, by name.
///
/// Read through the CLI's own walk rather than by a rule copied here, so a
/// package that stops being found is a failing test instead of two rules that
/// disagree.
Map<String, Directory> frameworkPackages() => <String, Directory>{
  for (final Package package in Packages.load(root: packagesRoot).all) package.name: package.directory,
};

/// Every profile the framework's packages declare between them.
///
/// `worker` is not one of them. It belongs to the socle, and it is switched on
/// by `scribe run --worker` rather than by mounting anything.
const Set<String> packageProfiles = <String>{'realtime', 'search'};

/// The capacity the framework declares, socle and packages together.
///
/// This reads the files that ship rather than a fixture: a weight edited in the
/// repository has to move these tests, which is the point of keeping them here.
Capacity frameworkCapacity({Set<String> profiles = packageProfiles}) =>
    frameworkCapacityOf(frameworkPackages().keys, profiles: profiles);

/// The capacity of the socle plus the packages named by [names].
///
/// The socle is always in, because its services are the ones no selection can
/// drop. [names] takes package names, the way `config.yaml` writes them, and
/// [profiles] the Compose profiles that selection switches on.
Capacity frameworkCapacityOf(Iterable<String> names, {Set<String> profiles = packageProfiles}) {
  final Map<String, Directory> packages = frameworkPackages();

  return Capacity.read(
    socleServices.map((Directory d) => d.childFile('$capacityFileName$kTemplateSuffix')),
    names.expand((String name) => opsDirectories(packages[name]!).map((Directory d) => d.childFile(capacityFileName))),
    profiles: profiles,
  );
}
