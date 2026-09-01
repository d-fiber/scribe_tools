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
import 'package:scribe_tools/src/nodes.dart';
import 'package:scribe_tools/src/ops/fragments.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// The fragment a package uses to declare its own gateway services and routes.
const String gatewayTemplate = 'kong.yml';

/// The script the gateway runs before starting, which fills the keys in.
const String gatewayEntrypointName = 'kong-entrypoint.sh';

/// The file the gateway reads, and the name the base template carries.
const String gatewayFileName = 'kong.yml';

/// A route the assembled gateway declares, and where it came from.
///
/// The origin is the whole point: Kong refuses a duplicated route name with a
/// line number, and accepts a duplicated path without a word, so the only place
/// either can be reported against the package that wrote it is here.
class GatewayRoute {
  /// Records a route named [name] serving [paths], declared by [origin].
  const GatewayRoute({required this.name, required this.paths, required this.origin});

  /// The route's name, unique across the whole document or Kong refuses to start.
  final String name;

  /// The paths this route answers, as the document writes them.
  final List<String> paths;

  /// The label of the fragment that declared it, or `socle` for the base.
  final String origin;
}

/// The environment lines that carry the key of every node that asks for one.
///
/// One line per keyed node, named after it, so a key a project writes in its own
/// environment reaches the gateway container. Without them the entry point finds
/// the variable unset, drops the credential slot, and the node answers 401 to
/// every key it is handed while Kong still reports itself healthy.
String nodeKeyVariables(Project project) => Nodes.load(project: project).facingOutward
    .where((ProjectNode node) => node.requiresApiKey)
    .map((ProjectNode node) => '${node.name.toUpperCase()}_KEYS=\${${node.name.toUpperCase()}_KEYS}')
    .join('\n');

/// Renders the gateway configuration the whole selection adds up to.
///
/// It is the second half of an assembly and it did not exist: the base template
/// ships, every package may carry its own `kong.yml`, the compose mounts the
/// result, and nothing wrote it. A stack started without it hands Kong a
/// directory the daemon created in place of the missing file, and Kong dies on
/// a parse error three layers from the cause.
class GatewayRender {
  /// Renders the gateway of [project].
  GatewayRender({Project? project}) : project = project ?? globals.project;

  /// The project whose manifest decides the origins.
  final Project project;

  /// Writes the merged configuration into [target], and returns the file.
  ///
  /// [values] carries what the compose render already resolved, so the identity
  /// of the project is written once and read here.
  Future<File> render(Directory target, Map<String, String> values, List<Package> active) async {
    final File source = globals.templatePaths
        .directoryInPackage(kSocleTemplatesDirectoryName, globals.fs)
        .childDirectory(servicesDirectoryName)
        .childDirectory('gateway')
        .childFile('$gatewayFileName$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No gateway template at ${source.path}');
    }

    final Packages packages = Packages.load();
    final List<YamlFragment> fragments = packages.fragmentsFor(gatewayTemplate, active);
    final String merged = mergeYamlDocuments(await source.readAsString(), fragments);
    final String written = renderTemplate(gatewayFileName, merged, <String, String>{
      ...values,
      ..._gateway(Nodes.load(project: project).facingOutward, active, values['app_name_snake']!),
    });

    refuseAmbiguousRoutes(routesOf(written, fragments));

    if (!target.existsSync()) target.createSync(recursive: true);
    final File destination = target.childFile(gatewayFileName);
    await destination.writeAsString(written);
    await _renderEntrypoint(target, values);

    return destination;
  }

  /// Renders the script the gateway starts through, beside the document it fills.
  ///
  /// The compose runs it as an argument to `bash` rather than as the container's
  /// own executable, because a file written by the tool carries no execute bit
  /// and a mount does not add one.
  Future<void> _renderEntrypoint(Directory target, Map<String, String> values) async {
    final File source = globals.templatePaths
        .directoryInPackage(kSocleTemplatesDirectoryName, globals.fs)
        .childDirectory(servicesDirectoryName)
        .childDirectory('gateway')
        .childFile('$gatewayEntrypointName$kTemplateSuffix');
    if (!source.existsSync()) {
      throwToolExit('No gateway entrypoint template at ${source.path}');
    }

    await target
        .childFile(gatewayEntrypointName)
        .writeAsString(renderTemplate(gatewayEntrypointName, await source.readAsString(), values));
  }

  /// The values the gateway asks for, all of them derived from the project.
  ///
  /// Nothing here is a name the framework chose. The nodes come from the
  /// directories under `lib/src/`, and what each one gets comes from the
  /// manifest when it says something and from a default when it does not.
  Map<String, String> _gateway(List<ProjectNode> nodes, List<Package> active, String appNameSnake) {
    final String origins = _originsBlock(project.manifest.origins, 'api.cors');

    return <String, String>{
      'api_nodes': nodes
          .expand((ProjectNode node) => node.versions.map((String version) => _service(node, version)))
          .join('\n\n'),
      'api_node_acls': nodes.where(_keyed).map(_acl).join('\n'),
      'app_key_consumers': nodes.where(_keyed).map(_consumer).join('\n'),
      'codex_service': _codexService(appNameSnake, project.manifest.dashboard),
      for (final Package package in active) '${package.name}_cors_origins': origins,
    };
  }

  /// The service the dashboard reads its gauges through.
  ///
  /// It always answers `codex.<name>.scribe.localhost`, the host the proxy
  /// always serves the dashboard's own site on, so a checkout with no
  /// `dashboard:` named still has somewhere the page can read its gauges from
  /// during `scribe run`. A domain named in `dashboard:` answers the same
  /// route in addition, once one is set.
  ///
  /// Three conditions guard it and none alone is enough. The host match means
  /// a request on the public API domain never reaches the route at all, so the
  /// surface is not merely unadvertised there. The key and the group mean a
  /// browser that resolves one of these hosts still answers for itself,
  /// because a domain named in `dashboard:` is public DNS like any other. And
  /// the internal secret this route stamps on every request it forwards is
  /// what the host actually checks, `access()` in `codex/gauges.ts` requiring
  /// the `service` caller role: a call that reaches `api-upstream` on the app
  /// network without going through this route, key and host included, carries
  /// no secret it could have guessed, and is refused there instead.
  static String _codexService(String appNameSnake, String dashboard) {
    final String localHost = 'codex.$appNameSnake.scribe.localhost';
    final List<String> hosts = <String>[localHost];

    if (dashboard.isNotEmpty) {
      final String host = Uri.parse(dashboard).host;
      if (host.isEmpty) {
        throwToolExit('config.yaml declares a dashboard at "$dashboard", which names no host.');
      }
      if (host != localHost) hosts.add(host);
    }

    return <String>[
      '- name: codex',
      '  protocol: http',
      '  host: api-upstream',
      '  port: 3000',
      '  path: /_codex',
      '  read_timeout: 15000',
      '  write_timeout: 15000',
      '  connect_timeout: 15000',
      '  routes:',
      '    - name: codex-route',
      '      strip_path: true',
      '      methods:',
      '        - GET',
      '      hosts:',
      for (final String host in hosts) '        - $host',
      '      paths:',
      '        - /_codex',
      '  plugins:',
      '    - name: key-auth',
      '      config:',
      '        key_names:',
      '          - apikey',
      '        key_in_query: false',
      '    - name: acl',
      '      config:',
      '        allow:',
      '          - admin',
      // Stamped only once the host and key checks above already passed, and
      // only on this route: a caller who reaches the upstream any other way
      // never carries it, which is what `access()` on the host actually
      // checks. `remove` first refuses a client that tried to hand its own.
      '    - name: request-transformer',
      '      config:',
      '        remove:',
      '          headers:',
      '            - x-internal-secret',
      '        add:',
      '          headers:',
      '            - "x-internal-secret:\$INTERNAL_SECRET"',
      '    - name: rate-limiting',
      '      config:',
      '        second: 10',
      '        minute: 300',
      '        limit_by: ip',
      '        policy: local',
      '        fault_tolerant: true',
    ].join('\n');
  }

  String _originsBlock(List<String> origins, String field) {
    if (origins.isEmpty) {
      throwToolExit('config.yaml declares no $field, so the gateway would refuse every browser.');
    }

    return <String>['origins:', for (final String origin in origins) '  - "$origin"'].join('\n');
  }

  /// One Kong service and route per node, all of them reaching the same upstream.
  ///
  /// The path prefix is not decoration. The framework mounts its internal
  /// services at the root of the same port, so a service whose path were `/`
  /// would make `/v1/<node>/services/...` resolve to them straight from the
  /// public domain.
  String _service(ProjectNode node, String version) => <String>[
    '- name: ${node.serviceNameFor(version)}',
    '  protocol: http',
    '  host: api-upstream',
    '  port: 3000',
    '  path: ${node.upstreamPathFor(version)}',
    // The connect timeout stays the framework's: the upstream is a container on
    // the same network, so failing to open a connection to it is not a property
    // of the node but of the stack being down.
    '  read_timeout: ${node.timeoutSec * 1000}',
    '  write_timeout: ${node.timeoutSec * 1000}',
    '  connect_timeout: 15000',
    '  routes:',
    '    - name: ${node.serviceNameFor(version)}-route',
    '      strip_path: true',
    '      paths:',
    '        - ${node.publicPathFor(version)}',
    '  plugins:',
    '    - name: cors',
    '      config:',
    _indent(_originsBlock(node.origins, 'api.\${node.name}.origins'), '        '),
    '    - name: request-size-limiting',
    '      config:',
    '        allowed_payload_size: ${node.maxBodyMb}',
    '        size_unit: megabytes',
    if (node.requiresApiKey) ...<String>[
      '    - name: key-auth',
      '      config:',
      '        key_names:',
      '          - ${node.keyHeader}',
      '        key_in_query: false',
      '    - name: acl',
      '      config:',
      '        allow:',
      '          - ${node.aclGroup}',
    ],
    '    - name: rate-limiting',
    '      config:',
    '        second: ${node.callsPerSecond}',
    '        minute: ${node.callsPerMinute}',
    '        limit_by: ip',
    // A counter local to a worker is multiplied by the number of Kong workers
    // and replicas, so the quota would mean whatever the deployment happens to
    // be sized at. The shared store is what makes the number mean itself.
    '        policy: redis',
    '        redis:',
    '          host: redis',
    '          port: 6379',
    '          password: \$REDIS_PASSWORD',
    '          database: 0',
    '        fault_tolerant: true',
    '        hide_client_headers: false',
  ].join('\n');

  static bool _keyed(ProjectNode node) => node.requiresApiKey;

  String _acl(ProjectNode node) => <String>['- consumer: ${node.name}', '  group: ${node.aclGroup}'].join('\n');

  /// One consumer per node, holding the key slot the entry point fills.
  ///
  /// The entry point substitutes an environment variable per key line and drops
  /// the line when the variable is unset, so a project without a key for a node
  /// gets a consumer with no credential rather than a broken document.
  String _consumer(ProjectNode node) => <String>[
    '- username: ${node.name}',
    '  keyauth_credentials:',
    '    - key: \$${node.name.toUpperCase()}_KEYS',
  ].join('\n');

  String _indent(String block, String indent) =>
      block.split('\n').map((String line) => line.isEmpty ? line : '$indent$line').join('\n');
}

/// Every route the rendered document [written] declares, with its origin.
///
/// [fragments] is what was merged in, in the order it was merged, which is how
/// a route found past the base is attributed to the package that wrote it.
List<GatewayRoute> routesOf(String written, List<YamlFragment> fragments) {
  final Object? document = loadYaml(written);
  if (document is! YamlMap) return const <GatewayRoute>[];

  final Object? services = document['services'];
  if (services is! YamlList) return const <GatewayRoute>[];

  final Map<String, String> origins = _originOfService(written, fragments);

  return <GatewayRoute>[
    for (final Object? service in services)
      if (service is YamlMap)
        for (final Object? route in service['routes'] is YamlList ? service['routes']! as YamlList : const <Object?>[])
          if (route is YamlMap && route['name'] != null)
            GatewayRoute(
              name: '${route['name']}',
              paths: <String>[
                for (final Object? path in route['paths'] is YamlList ? route['paths']! as YamlList : const <Object?>[])
                  '$path',
              ],
              origin: origins['${service['name']}'] ?? 'socle',
            ),
  ];
}

Map<String, String> _originOfService(String written, List<YamlFragment> fragments) {
  final Map<String, String> origins = <String, String>{};

  for (final YamlFragment fragment in fragments) {
    // A fragment still carries its placeholders here, so it may not parse at
    // all. Failing to attribute a route is not worth failing the render for:
    // the collision is still refused, it is just reported without a name.
    Object? document;
    try {
      document = loadYaml(fragment.source);
    } on Object {
      continue;
    }
    if (document is! YamlMap) continue;

    final Object? services = document['services'];
    if (services is! YamlList) continue;

    for (final Object? service in services) {
      if (service is YamlMap && service['name'] != null) origins['${service['name']}'] = fragment.label;
    }
  }

  return origins;
}

/// Refuses a gateway whose routes cannot both be served.
///
/// Two routes of one name make Kong refuse to start, which is loud and already
/// handled. Two routes on the same path make Kong start, serve, and answer from
/// one of them, and the one it picks is derived from a hash of the route's name:
/// stable, reproducible, and impossible to predict by reading the file. It is
/// the only collision in the whole chain that no tool catches, which is why it
/// is caught here.
void refuseAmbiguousRoutes(List<GatewayRoute> routes) {
  final Map<String, List<GatewayRoute>> byName = <String, List<GatewayRoute>>{};
  final Map<String, List<GatewayRoute>> byPath = <String, List<GatewayRoute>>{};

  for (final GatewayRoute route in routes) {
    byName.putIfAbsent(route.name, () => <GatewayRoute>[]).add(route);
    for (final String path in route.paths) {
      byPath.putIfAbsent(path, () => <GatewayRoute>[]).add(route);
    }
  }

  for (final MapEntry<String, List<GatewayRoute>> entry in byName.entries) {
    if (entry.value.length < 2) continue;
    final String origins = entry.value.map((GatewayRoute route) => route.origin).join(', ');
    throwToolExit('Two gateway routes are named "${entry.key}", declared by: $origins. Kong refuses to start on that.');
  }

  for (final MapEntry<String, List<GatewayRoute>> entry in byPath.entries) {
    if (entry.value.length < 2) continue;
    final String named = entry.value.map((GatewayRoute route) => '${route.name} (${route.origin})').join(', ');
    throwToolExit(
      'Two gateway routes serve the path "${entry.key}": $named. '
      'Kong would start and answer from only one of them, picked from a hash of the route name.',
    );
  }
}
