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

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:scribe/src/dependencies.dart';
import 'package:scribe/src/ops/capacity.dart';

/// The framework repository, two levels above this package.
const String repository = '../../scribe';

const FileSystem _fs = LocalFileSystem();

/// Where the modules of the framework live, both roots.
///
/// `host/dependencies/` holds what the framework owns, `host/packages/` the
/// mounted packages. A render reads both, so a check on what ships has to.
List<Directory> get modulesRoots => <Directory>[
  _fs.directory(p.join(repository, 'host/dependencies')),
  _fs.directory(p.join(repository, 'host/packages')),
];

/// The socle's own ops directory, which holds the `capacity.yaml` every project reads.
Directory get socleOps => _fs.directory(p.join(repository, 'ops/docker'));

/// Where the socle's compose templates live, which is not next to its weights.
Directory get socleComposeTemplates => _fs.directory(p.join(repository, 'templates/ops/docker'));

/// A `capacity.yaml` and the compose document its weights have to agree with.
///
/// A module keeps both in the same directory, since neither is read without the
/// other. The socle does not: its compose carries `{{variables}}` and so lives
/// under `templates/`, while its weights are plain numbers and stay in `ops/`.
class CapacitySource {
  const CapacitySource({required this.weights, required this.compose});

  /// The directory holding the `capacity.yaml`.
  final Directory weights;

  /// The compose document declaring the services those weights name.
  final File compose;
}

/// Every `capacity.yaml` of the framework and the compose it goes with.
///
/// The socle comes first, then one per module, keyed the way a mismatch has to
/// be reported for a reader to know which file to open.
Map<String, CapacitySource> capacitySources() => <String, CapacitySource>{
  'ops/docker': CapacitySource(
    weights: socleOps,
    compose: socleComposeTemplates.childFile('docker-compose.yaml'),
  ),
  for (final MapEntry<String, Directory> module in frameworkModules().entries)
    for (final Directory subject in opsDirectories(module.value))
      _sourceKey(module.key, module.value, subject): CapacitySource(
        weights: subject,
        compose: subject.childFile('docker-compose.yaml'),
      ),
};

/// The directories of [module] that may hold a `capacity.yaml`.
///
/// A package groups its ops by subject, so the weights of the cache sit in
/// `ops/valkery/` while a module that ships one container keeps them in `ops/`.
List<Directory> opsDirectories(Directory module) {
  final Directory ops = module.childDirectory('ops');
  if (!ops.existsSync()) return const <Directory>[];

  return <Directory>[
    if (ops.childFile(capacityFileName).existsSync()) ops,
    ...ops.listSync().whereType<Directory>(),
  ];
}

/// How a mismatch names the file to open.
String _sourceKey(String module, Directory root, Directory subject) =>
    subject.path == root.childDirectory('ops').path ? module : '$module/${p.basename(subject.path)}';

/// Every module of the framework, by module path.
///
/// Read through the CLI's own walk rather than by a rule copied here, so a
/// module that stops being found is a failing test instead of two rules that
/// disagree.
Map<String, Directory> frameworkModules() => <String, Directory>{
  for (final Dependency dependency in Dependencies.load(roots: modulesRoots).all)
    dependency.path: dependency.directory,
};

/// Every profile the framework's modules declare between them.
///
/// `worker` is not one of them. It belongs to the socle, and it is switched on
/// by the project's own `worker:` key rather than by mounting anything.
const Set<String> moduleProfiles = <String>{'ops', 'realtime', 'reco', 'search'};

/// The capacity the framework declares, socle and modules together.
///
/// This reads the files that ship rather than a fixture: a weight edited in the
/// repository has to move these tests, which is the point of keeping them here.
Capacity frameworkCapacity({Set<String> profiles = moduleProfiles}) =>
    frameworkCapacityOf(frameworkModules().keys, profiles: profiles);

/// The capacity of the socle plus the modules named by [paths].
///
/// The socle is always in, because its services are the ones no selection can
/// drop. [paths] takes module addresses, the way `config.yaml` names them, and
/// [profiles] the Compose profiles that selection switches on.
Capacity frameworkCapacityOf(Iterable<String> paths, {Set<String> profiles = moduleProfiles}) {
  final Map<String, Directory> modules = frameworkModules();

  return Capacity.read(
    _fs.directory(p.join(repository, 'ops/docker')),
    paths.expand((String path) => opsDirectories(modules[path]!).map((Directory d) => d.childFile(capacityFileName))),
    profiles: profiles,
  );
}
