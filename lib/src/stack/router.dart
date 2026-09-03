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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/templates.dart';

/// The compose project the router runs under, which is not a project's own.
const String routerProjectName = 'scribe_router';

/// The container the router runs in, named by Compose from the project above.
const String routerContainerName = 'scribe_router-router-1';

/// The single reverse proxy every project on a machine answers behind.
///
/// It owns port 80 and 443, and it is the only thing on the machine that does.
/// A project used to publish them itself, so the second project to start could
/// not bind them and died there; a machine has one pair of those ports and any
/// number of projects, so the ports cannot belong to a project.
///
/// It reads the routes from the labels a project's proxy carries, through the
/// Docker socket, so nothing has to be written to a shared file when a project
/// starts or stops. It holds no data of any project.
class Router {
  /// The router of the machine this command runs on.
  const Router();

  /// Starts the router if it is not up already, and returns whether it is.
  ///
  /// Idempotent, because every `scribe run` calls it and a machine has one.
  Future<bool> ensureUp() async {
    final File document = await _document();
    final int code = await globals.processRunner.run(
      commandArgv(DockerCompose.arg('-p').arg(routerProjectName).arg('-f').arg(document.path).up().arg('-d')),
    );

    return code == 0;
  }

  /// Joins the router to [network] so it can reach what answers on it.
  ///
  /// A project's network is its own, and the router is outside every project,
  /// so it has to be let in one network at a time. Joining a network it is
  /// already on is not an error and not worth a word.
  Future<void> attach(String network) async {
    await globals.processRunner.observe(
      commandArgv(Docker.network().arg('connect').arg(network).arg(routerContainerName)),
    );
  }

  /// The hostnames a running stack other than [projectName] already answers on.
  ///
  /// Two projects that claim one hostname is not something to work around: the
  /// second would be unreachable, or would steal the first, depending on which
  /// the router saw last. The caller refuses instead.
  Future<List<String>> hostnamesTakenBesides(String projectName) async {
    final String written = await globals.processRunner.capture(
      commandArgv(
        Docker.ps()
            .filter('label=traefik.enable=true')
            .format('{{.Label "com.docker.compose.project"}}\t{{.Label "scribe.hostnames"}}'),
      ),
    );

    return <String>[
      for (final String line in written.split('\n'))
        if (line.trim().isNotEmpty && !line.startsWith('$projectName\t'))
          ...line.split('\t').last.split(',').map((String host) => host.trim()).where((String h) => h.isNotEmpty),
    ];
  }

  Future<File> _document() async {
    final Directory into = globals.fs.systemTempDirectory.childDirectory('scribe-router')..createSync(recursive: true);

    final File source = SocleOps().root
        .childDirectory(routerDirectoryName)
        .childFile('docker-compose.yaml$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('The router template is missing from ${source.path}, so no project can be reached.');
    }

    return into.childFile('docker-compose.yaml')..writeAsStringSync(source.readAsStringSync());
  }
}
