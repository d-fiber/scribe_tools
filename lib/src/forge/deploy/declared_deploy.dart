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

import 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart';

export 'package:scribe_tools/src/forge/sql/declared_sql_schema.dart'
    show
        DeclaredSqlColumn,
        DeclaredSqlCompositeType,
        DeclaredSqlCronJob,
        DeclaredSqlEnum,
        DeclaredSqlFunction,
        DeclaredSqlTable,
        DeclaredSqlTrigger,
        SqlColumnType,
        SqlCronJobOptions,
        SqlFunctionOptions,
        SqlTriggerOptions;

/// A package's whole `deploy/`, exactly as its `deploy/deploy.ts` declared it under `@Deploy`.
class DeclaredDeploy {
  /// Holds what the bridge read off the package's one `@Deploy` declaration.
  const DeclaredDeploy({required this.db, required this.services, required this.recipes, required this.configuration});

  /// The SQL this package hands the database, by the moment it plays at.
  final DeclaredDb db;

  /// The containers this package starts, in the order it declared them.
  final List<DeclaredDeployService> services;

  /// The resource types this package answers for, in the order it declared them.
  final List<DeclaredDeployRecipe> recipes;

  /// What a project may tune and must place before this package can run.
  final DeclaredConfiguration configuration;

  /// Reads a whole `@Deploy` declaration from the JSON the bridge prints.
  factory DeclaredDeploy.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> options = json['options'] as Map<String, dynamic>;

    return DeclaredDeploy(
      db: DeclaredDb.fromJson(options['db'] as Map<String, dynamic>?),
      services: ((options['services'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DeclaredDeployService.fromJson(e as Map<String, dynamic>))
          .toList(),
      recipes: ((options['recipes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DeclaredDeployRecipe.fromJson(e as Map<String, dynamic>))
          .toList(),
      configuration: DeclaredConfiguration.fromJson(options['configuration'] as Map<String, dynamic>),
    );
  }
}

/// A value a deploy declaration can take: text taken as written, or one of the four tokens
/// `deploy/deploy.ts` can read back at render time.
sealed class DeployValue {
  const DeployValue();

  /// Reads one value from the JSON object the bridge prints.
  factory DeployValue.fromJson(Map<String, dynamic> json) => switch (json['kind'] as String) {
    'literal' => LiteralValue(json['value'] as String),
    'env' => EnvValue(json['name'] as String),
    'setting' => SettingValue(json['key'] as String),
    'sizingToken' => SizingTokenValue(json['name'] as String),
    'resource' => ResourceValue(name: json['name'] as String, field: json['field'] as String),
    'template' => TemplateValue(json['raw'] as String),
    final String other => throw StateError('Unknown deploy value kind "$other".'),
  };
}

/// A value taken exactly as written, with no substitution.
class LiteralValue extends DeployValue {
  /// Holds the literal [value].
  const LiteralValue(this.value);

  /// The text this value renders as.
  final String value;
}

/// A value read from the shell environment a stack starts under, `${name}` once rendered.
class EnvValue extends DeployValue {
  /// Holds the environment variable [name] this value reads.
  const EnvValue(this.name);

  /// The environment variable this value reads.
  final String name;
}

/// A value a project sets through `deploy/configuration.yaml`.
class SettingValue extends DeployValue {
  /// Holds the setting [key] this value reads.
  const SettingValue(this.key);

  /// The key this value reads.
  final String key;
}

/// A value the framework computes for one service at render time.
class SizingTokenValue extends DeployValue {
  /// Holds the sizing token [name] this value reads.
  const SizingTokenValue(this.name);

  /// The token name, without its `{{` and `}}`.
  final String name;
}

/// A value read from a placed resource's recipe, once it has answered.
class ResourceValue extends DeployValue {
  /// Holds the resource [name] and the contract [field] this value reads.
  const ResourceValue({required this.name, required this.field});

  /// The resource this value reads, by the name it was required under, or `"postgres"`.
  final String name;

  /// The contract key this value reads.
  final String field;
}

/// Raw text carrying its own `{{...}}` or `${...}` markers.
class TemplateValue extends DeployValue {
  /// Holds the raw text this value renders as.
  const TemplateValue(this.raw);

  /// The text this value renders as, verbatim.
  final String raw;
}

/// A `Record<string, DeployValue>` the bridge printed, read back in declaration order.
Map<String, DeployValue> _valueMap(Map<String, dynamic>? json) => (json ?? const <String, dynamic>{}).map(
  (String key, dynamic value) =>
      MapEntry<String, DeployValue>(key, DeployValue.fromJson(value as Map<String, dynamic>)),
);

/// What `db` took: one [DeclaredDeploySchema] per moment Postgres plays a package's SQL at.
class DeclaredDb {
  /// Holds the schema played at each moment.
  const DeclaredDb({required this.init, required this.migrations, required this.provisioning});

  /// Played once, at the container's own construction.
  final DeclaredDeploySchema init;

  /// Replayed at every start after the first.
  final DeclaredDeploySchema migrations;

  /// Played once, before `init`, and before the package's own schema exists.
  final DeclaredDeploySchema provisioning;

  /// Reads `db` from the JSON object the bridge prints, empty at every moment when it was left out.
  factory DeclaredDb.fromJson(Map<String, dynamic>? json) => DeclaredDb(
    init: DeclaredDeploySchema.fromJson(json?['init'] as Map<String, dynamic>?),
    migrations: DeclaredDeploySchema.fromJson(json?['migrations'] as Map<String, dynamic>?),
    provisioning: DeclaredDeploySchema.fromJson(json?['provisioning'] as Map<String, dynamic>?),
  );
}

/// Every SQL schema entry one `db` moment carries, grouped by kind.
class DeclaredDeploySchema {
  /// Holds one moment's schema entries, by kind.
  const DeclaredDeploySchema({
    required this.tables,
    required this.enums,
    required this.compositeTypes,
    required this.functions,
    required this.triggers,
    required this.cronJobs,
    required this.roles,
    required this.raw,
  });

  /// Whether this moment carries no entry of any kind, the ordinary case for `migrations`.
  bool get isEmpty =>
      tables.isEmpty &&
      enums.isEmpty &&
      compositeTypes.isEmpty &&
      functions.isEmpty &&
      triggers.isEmpty &&
      cronJobs.isEmpty &&
      roles.isEmpty &&
      raw.isEmpty;

  /// The tables this moment creates.
  final List<DeclaredSqlTable> tables;

  /// The enums this moment creates.
  final List<DeclaredSqlEnum> enums;

  /// The composite types this moment creates.
  final List<DeclaredSqlCompositeType> compositeTypes;

  /// The functions this moment creates.
  final List<DeclaredSqlFunction> functions;

  /// The triggers this moment creates.
  final List<DeclaredSqlTrigger> triggers;

  /// The scheduled jobs this moment creates.
  final List<DeclaredSqlCronJob> cronJobs;

  /// The roles this moment creates.
  final List<DeclaredRole> roles;

  /// The raw statements this moment runs.
  final List<String> raw;

  /// Reads one moment's schema from the JSON object the bridge prints, empty when it was left out.
  factory DeclaredDeploySchema.fromJson(Map<String, dynamic>? json) {
    final Map<String, dynamic> held = json ?? const <String, dynamic>{};

    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) reader) =>
        ((held[key] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) => reader(e as Map<String, dynamic>))
            .toList();

    return DeclaredDeploySchema(
      tables: listOf('tables', DeclaredSqlTable.fromJson),
      enums: listOf('enums', DeclaredSqlEnum.fromJson),
      compositeTypes: listOf('compositeTypes', DeclaredSqlCompositeType.fromJson),
      functions: listOf('functions', DeclaredSqlFunction.fromJson),
      triggers: listOf('triggers', DeclaredSqlTrigger.fromJson),
      cronJobs: listOf('cronJobs', DeclaredSqlCronJob.fromJson),
      roles: listOf('roles', DeclaredRole.fromJson),
      raw: ((held['raw'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => (e as Map<String, dynamic>)['sql'] as String)
          .toList(),
    );
  }
}

/// A Postgres role exactly as `Role` declared it.
class DeclaredRole {
  /// Holds the [name] and [passwordEnv] a role was declared with.
  const DeclaredRole({required this.name, required this.passwordEnv, required this.attributes});

  /// The role's own name.
  final String name;

  /// The environment variable a deployment reads this role's password from.
  final String passwordEnv;

  /// The attributes this role is created with.
  final List<String> attributes;

  /// Reads one role from the JSON object the bridge prints.
  factory DeclaredRole.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> options = json['options'] as Map<String, dynamic>;

    return DeclaredRole(
      name: json['name'] as String,
      passwordEnv: options['passwordEnv'] as String,
      attributes: ((options['attributes'] as List<dynamic>?) ?? const <String>['LOGIN']).cast<String>(),
    );
  }
}

/// One service, exactly as `Service` declared it.
class DeclaredDeployService {
  /// Holds the [name] and [options] a service was declared with.
  const DeclaredDeployService({required this.name, required this.options});

  /// The name this service is created under.
  final String name;

  /// Everything the service was declared with.
  final DeclaredServiceOptions options;

  /// Reads one service from the JSON object the bridge prints.
  factory DeclaredDeployService.fromJson(Map<String, dynamic> json) => DeclaredDeployService(
    name: json['name'] as String,
    options: DeclaredServiceOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// Where a service's image comes from.
sealed class DeclaredServiceSource {
  const DeclaredServiceSource();

  /// Reads a source from the JSON object the bridge prints.
  factory DeclaredServiceSource.fromJson(Map<String, dynamic> json) => switch (json['kind'] as String) {
    'image' => DeclaredImageSource(json['reference'] as String),
    'build' => DeclaredBuildSource(json['dockerfile'] as String? ?? 'Dockerfile'),
    final String other => throw StateError('Unknown service source kind "$other".'),
  };
}

/// A service that runs an image pulled from a registry.
class DeclaredImageSource extends DeclaredServiceSource {
  /// Holds the image [reference].
  const DeclaredImageSource(this.reference);

  /// The image reference, tag included.
  final String reference;
}

/// A service built from a `Dockerfile` beside `deploy/deploy.ts`.
class DeclaredBuildSource extends DeclaredServiceSource {
  /// Holds the [dockerfile] name.
  const DeclaredBuildSource(this.dockerfile);

  /// The Dockerfile's name, resolved against the service's own directory.
  final String dockerfile;
}

/// A `HealthCheck`, exactly as declared.
class DeclaredHealthCheck {
  /// Holds a health check exactly as the bridge printed it.
  const DeclaredHealthCheck({
    required this.command,
    required this.interval,
    required this.timeout,
    required this.retries,
    required this.startPeriod,
  });

  /// The command Compose runs inside the container to check it.
  final List<String> command;

  /// How long Compose waits between two checks.
  final String interval;

  /// How long one check is given to answer before it counts as failed.
  final String timeout;

  /// How many failures in a row before the container counts as unhealthy.
  final int retries;

  /// How long a container is given to become healthy before a failure counts against it.
  final String startPeriod;

  /// Reads a health check from the JSON object the bridge prints, null when the service carries none.
  static DeclaredHealthCheck? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    return DeclaredHealthCheck(
      command: (json['command'] as List<dynamic>).cast<String>(),
      interval: json['interval'] as String,
      timeout: json['timeout'] as String,
      retries: json['retries'] as int,
      startPeriod: json['startPeriod'] as String,
    );
  }
}

/// A `ServiceCapacity`, exactly as declared.
class DeclaredCapacity {
  /// Holds a capacity exactly as the bridge printed it.
  const DeclaredCapacity({
    required this.weight,
    required this.runtime,
    required this.min,
    required this.dev,
    this.cpuShares,
    this.cpuSharesTotal,
  });

  /// This service's share of the machine, relative to every other service's weight.
  final int weight;

  /// The language runtime this service's image carries.
  final String runtime;

  /// The smallest memory this service is ever sized down to.
  final String min;

  /// The memory this service is sized to on a workstation.
  final String dev;

  /// This service's fixed CPU share. Null when it scales with the cores it is given instead.
  final int? cpuShares;

  /// This service's CPU share, spread across the cores it is given. Null when it is fixed instead.
  final int? cpuSharesTotal;

  /// Reads a capacity from the JSON object the bridge prints, null when the service carries none.
  static DeclaredCapacity? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    return DeclaredCapacity(
      weight: json['weight'] as int,
      runtime: json['runtime'] as String,
      min: json['min'] as String,
      dev: json['dev'] as String,
      cpuShares: json['cpuShares'] as int?,
      cpuSharesTotal: json['cpuSharesTotal'] as int?,
    );
  }
}

/// A `KongRoute`, exactly as declared.
class DeclaredKongRoute {
  /// Holds a route exactly as the bridge printed it.
  const DeclaredKongRoute({required this.name, required this.paths, required this.stripPath});

  /// This route's own name.
  final String name;

  /// The path prefixes this route matches.
  final List<String> paths;

  /// Whether the matched prefix is removed before the request reaches this service.
  final bool stripPath;

  /// Reads one route from the JSON object the bridge prints.
  factory DeclaredKongRoute.fromJson(Map<String, dynamic> json) => DeclaredKongRoute(
    name: json['name'] as String,
    paths: (json['paths'] as List<dynamic>).cast<String>(),
    stripPath: json['stripPath'] as bool? ?? true,
  );
}

/// A `KongPlugin`, exactly as declared.
class DeclaredKongPlugin {
  /// Holds a plugin exactly as the bridge printed it.
  const DeclaredKongPlugin({required this.name, required this.config});

  /// The plugin's name, as Kong's own catalogue names it.
  final String name;

  /// The plugin's configuration, read exactly as Kong itself reads it.
  final Map<String, dynamic> config;

  /// Reads one plugin from the JSON object the bridge prints.
  factory DeclaredKongPlugin.fromJson(Map<String, dynamic> json) => DeclaredKongPlugin(
    name: json['name'] as String,
    config: (json['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
  );
}

/// A `KongService`, exactly as declared.
class DeclaredKongService {
  /// Holds a gateway service exactly as the bridge printed it.
  const DeclaredKongService({required this.name, required this.url, required this.routes, required this.plugins});

  /// This gateway service's own name.
  final String name;

  /// The internal URL Kong forwards a matched request to.
  final String url;

  /// The routes that reach this gateway service.
  final List<DeclaredKongRoute> routes;

  /// The plugins attached to this gateway service, in the order Kong is told to run them.
  final List<DeclaredKongPlugin> plugins;

  /// Reads a gateway service from the JSON object the bridge prints, null when the service carries none.
  static DeclaredKongService? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    return DeclaredKongService(
      name: json['name'] as String,
      url: json['url'] as String,
      routes: (json['routes'] as List<dynamic>)
          .map((dynamic e) => DeclaredKongRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
      plugins: ((json['plugins'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DeclaredKongPlugin.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A `ServiceOptions`, exactly as declared.
class DeclaredServiceOptions {
  /// Holds a service's options exactly as the bridge printed them.
  const DeclaredServiceOptions({
    required this.source,
    required this.networks,
    required this.restart,
    required this.profiles,
    required this.securityOpt,
    required this.capDrop,
    required this.capAdd,
    required this.volumes,
    required this.environment,
    required this.healthcheck,
    required this.dependsOn,
    required this.loggingMaxSize,
    required this.loggingMaxFile,
    required this.command,
    required this.ulimits,
    required this.capacity,
    required this.tuning,
    required this.kong,
  });

  /// Where this service's image comes from.
  final DeclaredServiceSource source;

  /// The networks this service attaches to, by name, each naming its aliases when it declared any.
  final Map<String, List<String>> networks;

  /// How Compose restarts this service when it exits.
  final String restart;

  /// The Compose profiles this service starts under.
  final List<String> profiles;

  /// `security_opt` entries this service's container carries.
  final List<String> securityOpt;

  /// Linux capabilities dropped from this service's container.
  final List<String> capDrop;

  /// Linux capabilities added back to this service's container.
  final List<String> capAdd;

  /// `"<source>:<target>[:<mode>]"` volume mounts.
  final List<String> volumes;

  /// This service's environment, by variable name.
  final Map<String, DeployValue> environment;

  /// What proves this service's container is answering. Null when never checked.
  final DeclaredHealthCheck? healthcheck;

  /// The services this one waits for, and what condition it waits for, by name.
  final Map<String, String> dependsOn;

  /// The largest a single log file grows to before it rotates. `10m` when the service declared none.
  final String loggingMaxSize;

  /// How many rotated files are kept. `3` when the service declared none.
  final int loggingMaxFile;

  /// The command this service's container runs instead of its image's own entrypoint. Empty when unset.
  final List<String> command;

  /// Resource limits raised for this service's container, by the POSIX limit they raise.
  final Map<String, DeclaredUlimit> ulimits;

  /// How this service is weighed when a deployment sizes memory and CPU. Null when it carries none.
  final DeclaredCapacity? capacity;

  /// Environment overrides read once a deployment has been sized, by variable name.
  final Map<String, DeployValue> tuning;

  /// What this service answers behind the gateway. Null when it is not reachable through it.
  final DeclaredKongService? kong;

  /// Reads a service's options from the JSON object the bridge prints.
  factory DeclaredServiceOptions.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? logging = json['logging'] as Map<String, dynamic>?;

    return DeclaredServiceOptions(
      source: DeclaredServiceSource.fromJson(json['source'] as Map<String, dynamic>),
      networks: _networksOf(json['networks']),
      restart: json['restart'] as String? ?? 'unless-stopped',
      profiles: ((json['profiles'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      securityOpt: ((json['securityOpt'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      capDrop: ((json['capDrop'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      capAdd: ((json['capAdd'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      volumes: ((json['volumes'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      environment: _valueMap(json['environment'] as Map<String, dynamic>?),
      healthcheck: DeclaredHealthCheck.fromJson(json['healthcheck'] as Map<String, dynamic>?),
      dependsOn: ((json['dependsOn'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).cast<String, String>(),
      loggingMaxSize: logging?['maxSize'] as String? ?? '10m',
      loggingMaxFile: logging?['maxFile'] as int? ?? 3,
      command: ((json['command'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
      ulimits: ((json['ulimits'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).map(
        (String name, dynamic value) =>
            MapEntry<String, DeclaredUlimit>(name, DeclaredUlimit.fromJson(value as Map<String, dynamic>)),
      ),
      capacity: DeclaredCapacity.fromJson(json['capacity'] as Map<String, dynamic>?),
      tuning: _valueMap(json['tuning'] as Map<String, dynamic>?),
      kong: DeclaredKongService.fromJson(json['kong'] as Map<String, dynamic>?),
    );
  }
}

/// `networks` read back as a name to alias-list map, whichever of the two shapes `deploy.ts` wrote.
Map<String, List<String>> _networksOf(dynamic json) {
  if (json is List<dynamic>) {
    return <String, List<String>>{for (final dynamic name in json) name as String: const <String>[]};
  }

  return (json as Map<String, dynamic>).map(
    (String name, dynamic attachment) => MapEntry<String, List<String>>(
      name,
      ((attachment as Map<String, dynamic>?)?['aliases'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
    ),
  );
}

/// A `UlimitValue`, exactly as declared.
class DeclaredUlimit {
  /// Holds a ulimit's [soft] and [hard] ceiling.
  const DeclaredUlimit({required this.soft, required this.hard});

  /// The ceiling a process can raise itself to without a privileged call.
  final int soft;

  /// The ceiling nothing inside the container can raise past.
  final int hard;

  /// Reads one ulimit from the JSON object the bridge prints.
  factory DeclaredUlimit.fromJson(Map<String, dynamic> json) =>
      DeclaredUlimit(soft: json['soft'] as int, hard: json['hard'] as int);
}

/// One recipe, exactly as `Recipe` declared it.
class DeclaredDeployRecipe {
  /// Holds the [type] and [options] a recipe was declared with.
  const DeclaredDeployRecipe({required this.type, required this.options});

  /// The resource type this recipe answers for.
  final String type;

  /// The contract and the classes it was declared with.
  final DeclaredRecipeOptions options;

  /// Reads one recipe from the JSON object the bridge prints.
  factory DeclaredDeployRecipe.fromJson(Map<String, dynamic> json) => DeclaredDeployRecipe(
    type: json['type'] as String,
    options: DeclaredRecipeOptions.fromJson(json['options'] as Map<String, dynamic>),
  );
}

/// A `RecipeOptions`, exactly as declared.
class DeclaredRecipeOptions {
  /// Holds a recipe's [contract] and [classes].
  const DeclaredRecipeOptions({required this.contract, required this.classes});

  /// The keys every class of this recipe must answer.
  final List<String> contract;

  /// One class per way a project can satisfy this resource type, by the name a target names it with.
  final Map<String, DeclaredRecipeClass> classes;

  /// Reads a recipe's options from the JSON object the bridge prints.
  factory DeclaredRecipeOptions.fromJson(Map<String, dynamic> json) => DeclaredRecipeOptions(
    contract: (json['contract'] as List<dynamic>).cast<String>(),
    classes: (json['classes'] as Map<String, dynamic>).map(
      (String name, dynamic value) =>
          MapEntry<String, DeclaredRecipeClass>(name, DeclaredRecipeClass.fromJson(value as Map<String, dynamic>)),
    ),
  );
}

/// A recipe class, exactly as `Outputs` or `Terraform` declared it.
sealed class DeclaredRecipeClass {
  const DeclaredRecipeClass();

  /// Reads one class from the JSON object the bridge prints.
  factory DeclaredRecipeClass.fromJson(Map<String, dynamic> json) => switch (json['kind'] as String) {
    'outputs' => DeclaredOutputsClass(_valueMap(json['outputs'] as Map<String, dynamic>?)),
    'terraform' => DeclaredTerraformClass(
      document: json['document'] as Map<String, dynamic>,
      params: json['params'] as Map<String, dynamic>,
    ),
    final String other => throw StateError('Unknown recipe class kind "$other".'),
  };
}

/// A recipe class that answers a resource's contract immediately, creating nothing.
class DeclaredOutputsClass extends DeclaredRecipeClass {
  /// Holds the [outputs] this class answers a resource's contract with.
  const DeclaredOutputsClass(this.outputs);

  /// The contract's keys, each answered with a value.
  final Map<String, DeployValue> outputs;
}

/// A recipe class that provisions its answer through OpenTofu.
class DeclaredTerraformClass extends DeclaredRecipeClass {
  /// Holds the [document] `tofu apply` runs, and the [params] its placeholders default to.
  const DeclaredTerraformClass({required this.document, required this.params});

  /// The document `tofu apply` runs, whose `output` block answers the resource's contract.
  final Map<String, dynamic> document;

  /// The values this document's placeholders take beyond what a project's own `params:` supplies.
  final Map<String, dynamic> params;
}

/// A `ConfigurationOptions`, exactly as declared.
class DeclaredConfiguration {
  /// Holds a package's configuration exactly as the bridge printed it.
  const DeclaredConfiguration({required this.settings, required this.requires, required this.env});

  /// The settings a project may tune, by the key `setting()` reads back.
  final Map<String, DeclaredSetting> settings;

  /// The resources this package needs placed before it can run.
  final List<DeclaredRequiredResource> requires;

  /// This package's own slice of the stack's environment, by variable name.
  final Map<String, DeployValue> env;

  /// Reads a configuration from the JSON object the bridge prints.
  factory DeclaredConfiguration.fromJson(Map<String, dynamic> json) => DeclaredConfiguration(
    settings: ((json['settings'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).map(
      (String key, dynamic value) =>
          MapEntry<String, DeclaredSetting>(key, DeclaredSetting.fromJson(value as Map<String, dynamic>)),
    ),
    requires: ((json['requires'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => DeclaredRequiredResource.fromJson(e as Map<String, dynamic>))
        .toList(),
    env: _valueMap(json['env'] as Map<String, dynamic>?),
  );
}

/// A `SettingOptions`, exactly as declared.
class DeclaredSetting {
  /// Holds a setting exactly as the bridge printed it.
  const DeclaredSetting({required this.doc, required this.type, required this.defaultValue});

  /// What this setting controls.
  final String doc;

  /// The shape a project's own value must take: `integer`, `boolean` or `string`.
  final String type;

  /// What this setting takes when a project leaves it untouched.
  final Object defaultValue;

  /// Reads one setting from the JSON object the bridge prints.
  factory DeclaredSetting.fromJson(Map<String, dynamic> json) => DeclaredSetting(
    doc: json['doc'] as String,
    type: json['type'] as String,
    defaultValue: json['default'] as Object,
  );
}

/// A `RequiredResource`, exactly as declared.
class DeclaredRequiredResource {
  /// Holds a required resource's [name] and [type].
  const DeclaredRequiredResource({required this.name, required this.type});

  /// The name this package reaches the resource by, once placed.
  final String name;

  /// The resource type a recipe must answer.
  final String type;

  /// Reads one required resource from the JSON object the bridge prints.
  factory DeclaredRequiredResource.fromJson(Map<String, dynamic> json) =>
      DeclaredRequiredResource(name: json['name'] as String, type: json['type'] as String);
}
