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
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/base/template.dart';
import 'package:scribe_tools/src/globals.dart' as globals;
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/templates.dart';

/// The file the reverse proxy reads, and the name the template carries.
const String proxyFileName = 'Caddyfile';

/// Renders the configuration of the proxy that stands in front of the gateway.
///
/// It is rendered rather than shipped in the framework checkout because the
/// stack must not read anything from a tree the project does not own: the
/// checkout is read-only as far as a running deployment is concerned, and a
/// configuration mounted from it would make the version of the proxy depend on
/// which framework happens to sit next to the project.
///
/// It carries no route of its own. The proxy answers two domains, hands
/// everything on the first to the gateway, and serves the dashboard on the
/// second. Which paths exist is the gateway's answer, and duplicating it here
/// would give a request two places to be refused and one of them would drift.
class ProxyRender {
  /// Renders the proxy of [project].
  ProxyRender({Project? project}) : project = project ?? globals.project;

  /// The project the render belongs to.
  final Project project;

  /// Writes the configuration into [target], and returns the file.
  Future<File> render(Directory target, Map<String, String> values) async {
    final File source = globals.templatePaths
        .directoryInPackage(kOpsTemplatesDirectoryName, globals.fs)
        .childDirectory('proxy')
        .childFile('$proxyFileName$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No proxy template at ${source.path}');
    }

    final String written = renderTemplate(proxyFileName, await source.readAsString(), values);

    if (!target.existsSync()) target.createSync(recursive: true);
    final File destination = target.childFile(proxyFileName);
    await destination.writeAsString(written);

    return destination;
  }
}
