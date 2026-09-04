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

import 'package:scribe_tools/src/base/yaml.dart';
import 'package:scribe_tools/src/forge/deploy/declared_deploy.dart';
import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';
import 'package:scribe_tools/src/forge/sql/emit_sql.dart';

/// One file `emitDeploy` produced, its path relative to the package's `deploy/`.
class EmittedDeployFile {
  /// Holds one generated file's [path] and [content].
  const EmittedDeployFile({required this.path, required this.content});

  /// The file's path, relative to `deploy/`.
  final String path;

  /// The file's whole content.
  final String content;
}

/// Every file `deploy/`'s generated half carries, rendered from [deploy], [packageName]'s own
/// `@Deploy` declaration.
///
/// [handWrittenInit] says whether `deploy/db/init/` already carries real SQL nothing here wrote —
/// a package without a `schema/` still writes that SQL by hand, and `overlay.yaml` has to mount it
/// into `provision` whether or not `deploy.ts` itself declares anything under `db.init`, since
/// this function otherwise has no way to see the disk.
///
/// [dbMountRoot], when given, is the absolute path `overlay.yaml`'s `db/init`/`db/provisioning`
/// mounts are written against instead of the usual `{{sdk_root}}/packages/<packageName>/deploy/db`
/// — the real, checked-out path a hand-written package's SQL sits at. A rendered package's SQL
/// does not sit there: `ops/deploy_render.dart` writes it into a throwaway copy of `deploy/` under
/// the project's own generated directory, and passes that copy's own `db/` here so the mount
/// points at where the SQL actually is.
///
/// Nothing else here reads or writes a disk: [EmittedDeployFile.path] is relative, and it is the
/// caller — `ops/deploy_render.dart` at render time — that turns this list into what a stack
/// actually reads, the same division `emitSql` already keeps from `db/init/00_schema.sql`.
List<EmittedDeployFile> emitDeploy({
  required String packageName,
  required DeclaredDeploy deploy,
  required bool handWrittenInit,
  String? dbMountRoot,
}) {
  final Set<String> claimedVolumes = <String>{};
  final List<EmittedDeployFile> files = <EmittedDeployFile>[
    for (final DeclaredDeployService service in deploy.services) ..._serviceFiles(packageName, service, claimedVolumes),
    for (final DeclaredDeployRecipe recipe in deploy.recipes) ..._recipeFiles(recipe),
    EmittedDeployFile(path: 'configuration.yaml', content: _configurationYaml(deploy.configuration)),
    if (deploy.configuration.env.isNotEmpty)
      EmittedDeployFile(path: 'packages.env', content: _packagesEnv(packageName, deploy.configuration.env)),
    if (_overlayYaml(packageName, deploy, hasInit: handWrittenInit || !deploy.db.init.isEmpty, dbMountRoot: dbMountRoot)
        case final String overlay)
      EmittedDeployFile(path: 'overlay.yaml', content: overlay),
    if (_schemaSql(packageName, deploy.db.init) case final String sql)
      EmittedDeployFile(path: 'db/init/00_schema.sql', content: sql),
    if (_schemaSql(packageName, deploy.db.migrations) case final String sql)
      EmittedDeployFile(path: 'db/migrations/00_migrations.sql', content: sql),
    if (_provisioningSql(deploy.db.provisioning) case final String sql)
      EmittedDeployFile(path: 'db/provisioning/roles.sql', content: sql),
  ];

  return files;
}

/// Every file one `Service` carries: its compose fragment, and whichever of `capacity.yaml`,
/// `resources.yaml`, `replicas.yaml`, `tuning.yaml`, `kong.yml` its own options call for.
///
/// [claimedVolumes] is shared across every service of the same package, in declaration order: a
/// named volume two services of one package both mount, `storage-data` between `storage` and
/// `imgproxy`, is declared once, by whichever service reaches it first, since each service still
/// renders to its own fragment file and [mergeYamlDocuments] appends fragment bodies rather than
/// deduplicating them — two fragments declaring the same volume would merge into a document with
/// the same key twice, which no YAML parser accepts.
List<EmittedDeployFile> _serviceFiles(String packageName, DeclaredDeployService service, Set<String> claimedVolumes) {
  final String directory = 'services/${service.name}';
  final List<EmittedDeployFile> files = <EmittedDeployFile>[
    EmittedDeployFile(
      path: '$directory/docker-compose.yaml',
      content: _composeYaml(packageName, service, claimedVolumes),
    ),
  ];

  if (service.options.capacity case final DeclaredCapacity capacity) {
    files
      ..add(EmittedDeployFile(path: '$directory/capacity.yaml', content: _capacityYaml(service.name, capacity)))
      ..add(EmittedDeployFile(path: '$directory/resources.yaml', content: _resourcesYaml(service.name, capacity)));
    if (capacity.cpuSharesTotal != null) {
      files.add(EmittedDeployFile(path: '$directory/replicas.yaml', content: _replicasYaml(service.name)));
    }
  }

  if (service.options.tuning.isNotEmpty) {
    files.add(EmittedDeployFile(path: '$directory/tuning.yaml', content: _tuningYaml(packageName, service)));
  }

  if (service.options.kong case final DeclaredKongService kong) {
    files.add(EmittedDeployFile(path: '$directory/kong.yml', content: _kongYaml(packageName, kong)));
  }

  return files;
}

/// Every file one `Recipe` carries: its `contract.yaml`, and one file per class, `.yaml` for an
/// `Outputs` class, `.tf.json` and `.params.json` for a `Terraform` class.
List<EmittedDeployFile> _recipeFiles(DeclaredDeployRecipe recipe) {
  final String directory = 'recipes/${recipe.type}';
  final List<EmittedDeployFile> files = <EmittedDeployFile>[
    EmittedDeployFile(
      path: '$directory/contract.yaml',
      content: renderYaml(<String, dynamic>{'outputs': recipe.options.contract}),
    ),
  ];

  recipe.options.classes.forEach((String name, DeclaredRecipeClass recipeClass) {
    switch (recipeClass) {
      case final DeclaredOutputsClass outputs:
        files.add(
          EmittedDeployFile(
            path: '$directory/$name.yaml',
            content: renderYaml(<String, dynamic>{
              'outputs': outputs.outputs.map(
                (String key, DeployValue value) => MapEntry<String, dynamic>(key, _yamlValueOf(value)),
              ),
            }),
          ),
        );
      case final DeclaredTerraformClass terraform:
        files.add(EmittedDeployFile(path: '$directory/$name.tf.json', content: _prettyJson(terraform.document)));
        files.add(EmittedDeployFile(path: '$directory/$name.params.json', content: _prettyJson(terraform.params)));
    }
  });

  return files;
}

String _prettyJson(Map<String, dynamic> document) => '${const JsonEncoder.withIndent('  ').convert(document)}\n';

/// The compose fragment one service renders to, its own container plus whichever of the named
/// volumes it mounts are not already claimed, by this call, in [claimedVolumes].
String _composeYaml(String packageName, DeclaredDeployService service, Set<String> claimedVolumes) {
  final DeclaredServiceOptions options = service.options;
  final Map<String, dynamic> container = <String, dynamic>{
    if (options.securityOpt.isNotEmpty) 'security_opt': options.securityOpt,
    if (options.capDrop.isNotEmpty) 'cap_drop': options.capDrop,
    if (options.capAdd.isNotEmpty) 'cap_add': options.capAdd,
    'networks': _networksValue(options.networks),
    if (options.profiles.isNotEmpty) 'profiles': options.profiles,
    ..._sourceValue(packageName, service.name, options.source),
    'restart': options.restart,
    if (options.volumes.isNotEmpty) 'volumes': options.volumes,
    if (options.environment.isNotEmpty)
      'environment': options.environment.map(
        (String key, DeployValue value) =>
            MapEntry<String, dynamic>(key, _yamlValueOf(value, packageName: packageName)),
      ),
    if (options.healthcheck case final DeclaredHealthCheck health) 'healthcheck': _healthcheckValue(health),
    if (options.dependsOn.isNotEmpty)
      'depends_on': options.dependsOn.map(
        (String name, String condition) =>
            MapEntry<String, dynamic>(name, <String, dynamic>{'condition': _dependsOnCondition(condition)}),
      ),
    'logging': <String, dynamic>{
      'driver': 'json-file',
      'options': <String, dynamic>{'max-size': options.loggingMaxSize, 'max-file': '${options.loggingMaxFile}'},
    },
    if (options.command.isNotEmpty) 'command': options.command,
    if (options.ulimits.isNotEmpty)
      'ulimits': options.ulimits.map(
        (String name, DeclaredUlimit limit) =>
            MapEntry<String, dynamic>(name, <String, dynamic>{'soft': limit.soft, 'hard': limit.hard}),
      ),
  };

  final List<String> namedVolumes = _namedVolumesOf(
    options.volumes,
  ).where((String name) => claimedVolumes.add(name)).toList();

  return renderYaml(<String, dynamic>{
    'services': <String, dynamic>{service.name: container},
    if (namedVolumes.isNotEmpty) 'volumes': <String, dynamic>{for (final String name in namedVolumes) name: null},
  });
}

/// `condition` (`"started"`, `"healthy"`, `"completed"`) turned into Compose's own three values.
String _dependsOnCondition(String condition) => switch (condition) {
  'healthy' => 'service_healthy',
  'completed' => 'service_completed_successfully',
  _ => 'service_started',
};

/// `networks`, as a bare list when nothing declared an alias, a map otherwise.
dynamic _networksValue(Map<String, List<String>> networks) {
  if (networks.values.every((List<String> aliases) => aliases.isEmpty)) return networks.keys.toList();

  return networks.map(
    (String name, List<String> aliases) =>
        MapEntry<String, dynamic>(name, aliases.isEmpty ? null : <String, dynamic>{'aliases': aliases}),
  );
}

/// The one or two top-level keys a service's source contributes: `image`, or `build`.
Map<String, dynamic> _sourceValue(String packageName, String serviceName, DeclaredServiceSource source) =>
    switch (source) {
      final DeclaredImageSource image => <String, dynamic>{'image': image.reference},
      final DeclaredBuildSource build => <String, dynamic>{
        'build': <String, dynamic>{
          'context': '{{sdk_root}}/packages/$packageName/deploy/services/$serviceName',
          'dockerfile': build.dockerfile,
        },
      },
    };

Map<String, dynamic> _healthcheckValue(DeclaredHealthCheck health) => <String, dynamic>{
  'test': health.command,
  'interval': health.interval,
  'timeout': health.timeout,
  'retries': health.retries,
  'start_period': health.startPeriod,
};

/// The named volumes `volumes` mounts: a source that is not an absolute path, does not start with
/// `./`, and does not start with `{{`.
List<String> _namedVolumesOf(List<String> volumes) {
  final List<String> named = <String>[];
  for (final String mount in volumes) {
    final String source = mount.split(':').first;
    if (source.startsWith('/') || source.startsWith('./') || source.startsWith('{{')) continue;
    if (!named.contains(source)) named.add(source);
  }
  return named;
}

/// `capacity.yaml`, one service entry, the only one this directory's fragment carries.
String _capacityYaml(String serviceName, DeclaredCapacity capacity) => renderYaml(<String, dynamic>{
  'services': <dynamic>[
    <String, dynamic>{
      'name': serviceName,
      'weight': capacity.weight,
      'runtime': capacity.runtime,
      'min': capacity.min,
      'dev': capacity.dev,
      if (capacity.cpuShares case final int shares) 'cpu_shares': shares,
      if (capacity.cpuSharesTotal case final int total) 'cpu_shares_total': total,
    },
  ],
});

/// `resources.yaml`, almost entirely mechanical: the memory tokens `ops/sizing_rules.dart`
/// computes for [serviceName] alone, plus its CPU share — `{{<name>_cpu_shares}}`, unquoted, when
/// [capacity] scales with the cores it is given (`cpuSharesTotal`), or [capacity]'s own fixed
/// `cpuShares` written as the number it is, when it does not.
String _resourcesYaml(String serviceName, DeclaredCapacity capacity) => renderYaml(<String, dynamic>{
  'services': <String, dynamic>{
    serviceName: <String, dynamic>{
      'cpu_shares': capacity.cpuSharesTotal != null ? RawYaml('{{${serviceName}_cpu_shares}}') : capacity.cpuShares,
      'memswap_limit': '{{${serviceName}_mem_limit}}',
      'deploy': <String, dynamic>{
        'resources': <String, dynamic>{
          'limits': <String, dynamic>{'memory': '{{${serviceName}_mem_limit}}'},
          'reservations': <String, dynamic>{'memory': '{{${serviceName}_mem_res}}'},
        },
      },
    },
  },
});

/// `replicas.yaml`, entirely mechanical, the same as `resources.yaml`.
String _replicasYaml(String serviceName) => renderYaml(<String, dynamic>{
  'services': <String, dynamic>{
    serviceName: <String, dynamic>{
      'deploy': <String, dynamic>{'replicas': RawYaml('{{${serviceName}_replicas}}')},
    },
  },
});

/// `tuning.yaml`, the environment overrides a service reads back once a deployment is sized.
String _tuningYaml(String packageName, DeclaredDeployService service) => renderYaml(<String, dynamic>{
  'services': <String, dynamic>{
    service.name: <String, dynamic>{
      'environment': service.options.tuning.map(
        (String key, DeployValue value) =>
            MapEntry<String, dynamic>(key, _yamlValueOf(value, packageName: packageName)),
      ),
    },
  },
});

/// `kong.yml`, one gateway service, its routes and its plugins.
///
/// A `cors` plugin is always the first of them, reading the origins `ops/gateway.dart` computes
/// for [packageName] on its own: every package's gateway route answers CORS the same way, so
/// nothing under `deploy.ts` declares it, the same reason `resources.yaml` needs nothing from a
/// service beyond its name.
String _kongYaml(String packageName, DeclaredKongService kong) => renderYaml(<String, dynamic>{
  'services': <dynamic>[
    <String, dynamic>{
      'name': kong.name,
      'url': kong.url,
      'routes': <dynamic>[
        for (final DeclaredKongRoute route in kong.routes)
          <String, dynamic>{'name': route.name, 'strip_path': route.stripPath, 'paths': route.paths},
      ],
      'plugins': <dynamic>[
        <String, dynamic>{'name': 'cors', 'config': RawYamlBlock('{{${packageName}_cors_origins}}')},
        for (final DeclaredKongPlugin plugin in kong.plugins)
          <String, dynamic>{'name': plugin.name, if (plugin.config.isNotEmpty) 'config': plugin.config},
      ],
    },
  ],
});

/// `configuration.yaml`, the settings a project may tune and the resources this package requires.
String _configurationYaml(DeclaredConfiguration configuration) => renderYaml(<String, dynamic>{
  if (configuration.settings.isNotEmpty)
    'settings': configuration.settings.map(
      (String key, DeclaredSetting setting) => MapEntry<String, dynamic>(key, <String, dynamic>{
        'doc': setting.doc,
        'type': setting.type,
        'default': setting.defaultValue,
      }),
    ),
  if (configuration.requires.isNotEmpty)
    'requires': <dynamic>[
      for (final DeclaredRequiredResource resource in configuration.requires)
        <String, dynamic>{'name': resource.name, 'type': resource.type},
    ],
});

/// `packages.env`, `KEY=value` lines, one per entry of `configuration.env`.
String _packagesEnv(String packageName, Map<String, DeployValue> env) {
  final StringBuffer out = StringBuffer();
  for (final MapEntry<String, DeployValue> entry in env.entries) {
    out.writeln('${entry.key}=${_envFileValueOf(entry.value, packageName: packageName)}');
  }
  return out.toString();
}

/// The mount that carries one provisioned role's SQL into `/provision/setup/`, numbered [prefix]
/// so every role's file runs before `db/init/`'s own.
String _provisioningRoleMount(String dbRoot, int prefix, String packageName, DeclaredRole role) =>
    '$dbRoot/provisioning/roles.sql:'
    '/provision/setup/$prefix-$packageName-${role.name}.sql:ro';

/// `overlay.yaml`, mounting `db/init/` and the provisioning SQL into the `provision` base service,
/// and carrying every provisioned role's password. Null when this package hands `provision`
/// nothing, which is the case for a package that requires no role and carries no `db/init/`.
String? _overlayYaml(String packageName, DeclaredDeploy deploy, {required bool hasInit, String? dbMountRoot}) {
  final List<DeclaredRole> roles = deploy.db.provisioning.roles;
  if (!hasInit && roles.isEmpty) return null;

  final String dbRoot = dbMountRoot ?? '{{sdk_root}}/packages/$packageName/deploy/db';
  int prefix = 50;
  final List<String> volumes = <String>[
    for (final DeclaredRole role in roles) _provisioningRoleMount(dbRoot, prefix++, packageName, role),
    if (hasInit) '$dbRoot/init:/provision/modules/$packageName:ro',
  ];

  return renderYaml(<String, dynamic>{
    'services': <String, dynamic>{
      'provision': <String, dynamic>{
        if (roles.isNotEmpty)
          'environment': <String, dynamic>{
            for (final DeclaredRole role in roles) role.passwordEnv: '\${${role.passwordEnv}}',
          },
        'volumes': volumes,
      },
    },
  });
}

/// The SQL `schema/` already knows how to render, reused for whatever `db.init` or `db.migrations`
/// carries. Null when the moment declares no table, enum, composite type, function, trigger or
/// scheduled job — the ordinary case for `migrations`.
String? _schemaSql(String packageName, DeclaredDeploySchema schema) {
  final bool empty =
      schema.tables.isEmpty &&
      schema.enums.isEmpty &&
      schema.compositeTypes.isEmpty &&
      schema.functions.isEmpty &&
      schema.triggers.isEmpty &&
      schema.cronJobs.isEmpty;
  if (empty && schema.raw.isEmpty) return null;

  final String generated = empty
      ? ''
      : emitSql(
          packageName: packageName,
          schema: DeclaredSqlSchema(
            enums: schema.enums,
            compositeTypes: schema.compositeTypes,
            tables: schema.tables,
            functions: schema.functions,
            triggers: schema.triggers,
            cronJobs: schema.cronJobs,
          ),
        );

  return '$generated${schema.raw.map((String statement) => '$statement\n').join()}';
}

/// The SQL `db.provisioning` carries: a role's own creation block per `Role`, then every raw
/// statement. Null when it declares neither.
String? _provisioningSql(DeclaredDeploySchema schema) {
  if (schema.roles.isEmpty && schema.raw.isEmpty) return null;

  final StringBuffer sql = StringBuffer();
  for (final DeclaredRole role in schema.roles) {
    sql.writeln(_roleSql(role));
  }
  for (final String statement in schema.raw) {
    sql.writeln(statement);
  }
  return sql.toString();
}

String _roleSql(DeclaredRole role) {
  final String attributes = (role.attributes.isEmpty ? const <String>['LOGIN'] : role.attributes).join(' ');

  return '\\getenv password ${role.passwordEnv}\n\n'
      'DO \$\$\n'
      'BEGIN\n'
      "  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${role.name}') THEN\n"
      '    CREATE ROLE ${role.name} $attributes;\n'
      '  END IF;\n'
      'END\n'
      '\$\$;\n\n'
      "ALTER USER ${role.name} WITH PASSWORD :'password';\n";
}

/// [value] rendered the way a YAML scalar reads it: a plain string, wrapped by `renderYaml` itself,
/// or the raw `{{...}}`/`${...}` text a token stands for.
dynamic _yamlValueOf(DeployValue value, {String? packageName}) => switch (value) {
  final LiteralValue literal => literal.value,
  final EnvValue env => '\${${env.name}}',
  final SettingValue setting => '{{setting_${packageName}_${setting.key}}}',
  final SizingTokenValue token => '{{${token.name}}}',
  final ResourceValue resource => '{{resource_${resource.name}_${resource.field}}}',
  final TemplateValue template => template.raw,
};

/// [value] rendered for `packages.env`, a bare `KEY=value` line rather than a quoted YAML scalar.
String _envFileValueOf(DeployValue value, {required String packageName}) {
  final dynamic rendered = _yamlValueOf(value, packageName: packageName);
  return rendered is String ? rendered : '$rendered';
}
