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
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/fragments.dart';
import 'package:scribe_tools/src/templates.dart';

/// The directory a service's own files sit in, under the ops templates.
const String servicesDirectoryName = 'services';

/// The directory the environment files a service reads sit in.
const String envDirectoryName = 'env';

/// The document every merged template is built onto.
const String stackTemplate = 'stack.yaml';

/// The templates that are merged into one document per name.
///
/// The order matters: Compose reads each later document as an override of the
/// earlier ones, so the base comes first and the sizing documents patch it.
const List<String> mergedTemplates = <String>['docker-compose.yaml', 'resources.yaml', 'replicas.yaml', 'tuning.yaml'];

/// The name of the file that says what a service costs, read and never written.
const String capacityTemplate = 'capacity.yaml';

/// The socle's own ops, laid out the way a package lays out its own.
///
/// One directory per service, each holding everything that service needs and
/// nothing another one does: its compose fragment, what it costs, and whatever
/// it mounts. Removing a service is removing its directory, and no other file
/// mentions it.
///
/// It is the same shape a package already uses under `ops/`, which is why the
/// merge that assembles a stack treats both the same way: the socle is a
/// package like the others as far as ops is concerned.
class SocleOps {
  /// Reads the ops templates that ship with the tool.
  SocleOps({Directory? root})
    : root = root ?? globals.templatePaths.directoryInPackage(kOpsTemplatesDirectoryName, globals.fs);

  /// The `ops/` directory of the templates, holding `services/` and `env/`.
  final Directory root;

  /// Every service directory, sorted so a merge never depends on the file system.
  List<Directory> get serviceDirectories {
    final Directory services = root.childDirectory(servicesDirectoryName);
    if (!services.existsSync()) return const <Directory>[];

    return services.listSync().whereType<Directory>().toList()
      ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  }

  /// The name of each service directory, which is what a mount path names.
  List<String> get serviceNames => <String>[for (final Directory d in serviceDirectories) p.basename(d.path)];

  /// The socle's slices of [template], one per service that declares one.
  List<YamlFragment> fragmentsFor(String template) => <YamlFragment>[
    for (final Directory service in serviceDirectories)
      if (service.childFile('$template$kTemplateSuffix') case final File file when file.existsSync())
        YamlFragment(p.basename(service.path), file.readAsStringSync()),
  ];

  /// The files of [service] that are copied beside the stack rather than merged.
  ///
  /// Everything a service directory holds that is not one of the merged
  /// documents and not its capacity: a Dockerfile, a configuration the container
  /// mounts, a script it runs. They are rendered like any other template and
  /// written under the stack, so a container never reads from the checkout.
  List<File> assetsOf(Directory service) {
    const Set<String> merged = <String>{...mergedTemplates, capacityTemplate};

    return service.listSync().whereType<File>().where((File file) {
      final String name = p.basename(file.path);
      if (!name.endsWith(kTemplateSuffix)) return false;

      return !merged.contains(name.substring(0, name.length - kTemplateSuffix.length));
    }).toList()..sort((File a, File b) => a.path.compareTo(b.path));
  }

  /// The environment files the socle declares, by the name a service reads them by.
  ///
  /// A file is an audience: what the host's own code reads, what reaches a
  /// datastore, what a mounted package adds. A package contributes to the ones
  /// its code needs, and a service lists the ones it reads. A variable is
  /// therefore declared once, by whoever reads it, instead of being repeated in
  /// every service that might.
  Map<String, String> get environments {
    final Directory env = root.childDirectory(envDirectoryName);
    if (!env.existsSync()) return const <String, String>{};

    return <String, String>{
      for (final File file
          in env.listSync().whereType<File>().toList()..sort((File a, File b) => a.path.compareTo(b.path)))
        if (p.basename(file.path).endsWith('.env$kTemplateSuffix'))
          p.basename(file.path).replaceAll(kTemplateSuffix, ''): file.readAsStringSync(),
    };
  }
}
