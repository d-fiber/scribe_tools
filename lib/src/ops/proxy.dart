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
import 'package:scribe_tools/src/ops/socle.dart';
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
/// It carries one route of its own, the dashboard's. The proxy hands
/// everything on the API's two hostnames to the gateway; which paths exist
/// there is the gateway's answer, and duplicating it here would give a
/// request two places to be refused and one of them would drift. The
/// dashboard is different: it is served from disk, not from the gateway, so
/// this is the only place that can serve it.
class ProxyRender {
  /// Renders the proxy of [project].
  ProxyRender({Project? project}) : project = project ?? globals.project;

  /// The project the render belongs to.
  final Project project;

  /// Writes the configuration into [target], and returns the file.
  Future<File> render(Directory target, Map<String, String> values) async {
    final File source = globals.templatePaths
        .directoryInPackage(kSocleTemplatesDirectoryName, globals.fs)
        .childDirectory(servicesDirectoryName)
        .childDirectory('proxy')
        .childFile('$proxyFileName$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No proxy template at ${source.path}');
    }

    final String written = renderTemplate(proxyFileName, await source.readAsString(), <String, String>{
      ...values,
      'dashboard_site': _dashboardSite(values['app_name_snake']!, project.manifest.dashboard),
    });

    if (!target.existsSync()) target.createSync(recursive: true);
    final File destination = target.childFile(proxyFileName);
    await destination.writeAsString('${written.trimRight()}\n');

    return destination;
  }

  /// The site block that serves the dashboard.
  ///
  /// It always answers on `codex.<name>.scribe.localhost`, which resolves to
  /// loopback on any machine without touching `/etc/hosts` or a deployed DNS
  /// record, so a checkout with no `dashboard:` named still has somewhere to
  /// reach the dashboard from during `scribe run`. The domain named in
  /// `dashboard:`, when there is one, answers the same content, in addition:
  /// both addresses share one block, since a request on either is served the
  /// same way.
  ///
  /// Read as a bare host rather than the value `dashboard:` carries verbatim:
  /// the scheme it may spell out describes what a browser sees, not what this
  /// container listens on, since the router in front of it is what terminates
  /// TLS. An address here that kept the scheme would ask Caddy to obtain and
  /// serve its own certificate for a domain it is never reached on directly.
  static String _dashboardSite(String appNameSnake, String dashboard) {
    final String localHost = 'codex.$appNameSnake.scribe.localhost';
    final String dashboardHost = dashboard.isEmpty ? '' : Uri.parse(dashboard).host;

    final List<String> addresses = <String>[
      'http://$localHost',
      if (dashboardHost.isNotEmpty && dashboardHost != localHost) dashboardHost,
    ];

    return <String>[
      '${addresses.join(', ')} {',
      '\tlog {',
      '\t\toutput stderr',
      '\t\tformat json',
      '\t\tlevel ERROR',
      '\t}',
      '\timport security_headers DENY',
      '\timport compression',
      '',
      // The gauges are read by the page this block serves, and by nothing else:
      // the gateway matches `/_codex` on these hosts only, and asks for a key
      // on top. Serving it from the public API domain would put a load report
      // behind a domain anyone knows.
      '\thandle_path /codex/* {',
      '\t\trewrite * /_codex{uri}',
      '\t\treverse_proxy kong:8000',
      '\t}',
      '',
      '\troot * /srv/web/codex',
      '',
      '\t@built file /index.html',
      '',
      '\thandle @built {',
      '\t\ttry_files {path} /index.html',
      '\t\tfile_server',
      '\t}',
      '',
      '\thandle {',
      '\t\trespond "The dashboard is not installed in this checkout." 404',
      '\t}',
      '}',
    ].join('\n');
  }
}
