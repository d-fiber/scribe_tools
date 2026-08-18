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

import 'dart:io';

import 'package:path/path.dart' as p;

class InfrastructureRoot {
  InfrastructureRoot(Directory root) : _self = root;

  final Directory _self;

  Directory get directory => _self;

  File get env => File(p.join(_self.path, '.env'));

  File get configExampleYaml => File(p.join(_self.path, 'config.example.yaml'));

  File get configYaml => File(p.join(_self.path, 'config.yaml'));

  File get koko => File(p.join(_self.path, 'koko'));

  File get makeSh => File(p.join(_self.path, 'make.sh'));

  File get binName => File(p.join(_self.path, '.bin_name'));

  File get kernelBinName => File(p.join(_self.path, '.kernel_bin_name'));

  File get tmpX25519Pem => File(p.join(_self.path, '.tmp_x25519.pem'));

  Alchemy get alchemy => Alchemy(_self);

  Scribe get scribe => Scribe(_self);
}

class Alchemy {
  Alchemy(Directory parent) : _self = Directory(p.join(parent.path, '.${p.basename(parent.path)}'));

  final Directory _self;

  Directory get directory => _self;

  AlchemyDocs get docs => AlchemyDocs(_self);

  AlchemyOps get ops => AlchemyOps(_self);
}

class AlchemyDocs {
  AlchemyDocs(Directory parent) : _self = Directory(p.join(parent.path, 'docs'));

  final Directory _self;

  Directory get directory => _self;

  File surface(String key) => File(p.join(_self.path, '$key.yaml'));

  AlchemyDocsDist get dist => AlchemyDocsDist(_self);
}

class AlchemyDocsDist {
  AlchemyDocsDist(Directory parent) : _self = Directory(p.join(parent.path, 'dist'));

  final Directory _self;

  Directory get directory => _self;

  Directory variant(String key) => Directory(p.join(_self.path, key));
}

class AlchemyOps {
  AlchemyOps(Directory parent) : _self = Directory(p.join(parent.path, 'ops'));

  final Directory _self;

  Directory get directory => _self;

  File get env => File(p.join(_self.path, '.env'));

  AlchemyOpsDocker get docker => AlchemyOpsDocker(_self);

  AlchemyOpsGateway get gateway => AlchemyOpsGateway(_self);
}

class AlchemyOpsDocker {
  AlchemyOpsDocker(Directory parent) : _self = Directory(p.join(parent.path, 'docker'));

  final Directory _self;

  Directory get directory => _self;

  File get dockerComposeYaml => File(p.join(_self.path, 'docker-compose.yaml'));
}

class AlchemyOpsGateway {
  AlchemyOpsGateway(Directory parent) : _self = Directory(p.join(parent.path, 'gateway'));

  final Directory _self;

  Directory get directory => _self;

  File get kongYml => File(p.join(_self.path, 'kong.yml'));
}

class Docker {
  Docker(Directory parent) : _self = Directory(p.join(parent.path, 'docker'));

  final Directory _self;

  Directory get directory => _self;

  File get dockerComposeYaml => File(p.join(_self.path, 'docker-compose.yaml'));

  File get sizingOverrideYaml => File(p.join(_self.path, 'sizing.override.yaml'));

  File get resourcesYaml => File(p.join(_self.path, 'resources.yaml'));

  File get replicasYaml => File(p.join(_self.path, 'replicas.yaml'));

  File get tuningYaml => File(p.join(_self.path, 'tuning.yaml'));
}

class Scribe {
  Scribe(Directory parent) : _self = Directory(p.join(parent.path, 'scribe'));

  final Directory _self;

  Directory get directory => _self;

  ScribeOps get ops => ScribeOps(_self);

  ScribeTemplates get templates => ScribeTemplates(_self);

  ScribePostgres get postgres => ScribePostgres(_self);

  Host get host => Host(_self);

  FoundationHosting get hosting => FoundationHosting(_self);

  FoundationOpensearch get opensearch => FoundationOpensearch(_self);

  FoundationStorage get storage => FoundationStorage(_self);
}

/// Written by hand: `docker/`, `gateway/` and `proxy/` were regrouped under
/// `scribe/ops/` after this tree was last generated.
///
/// This node holds only what the stack mounts or builds as it is. Everything
/// carrying a `{{variable}}` is under [ScribeTemplates] instead.
class ScribeOps {
  ScribeOps(Directory parent) : _self = Directory(p.join(parent.path, 'ops'));

  final Directory _self;

  Directory get directory => _self;

  Docker get docker => Docker(_self);

  ScribeOpsGateway get gateway => ScribeOpsGateway(_self);

  FoundationProxy get proxy => FoundationProxy(_self);
}

class ScribeOpsGateway {
  ScribeOpsGateway(Directory parent) : _self = Directory(p.join(parent.path, 'gateway'));

  final Directory _self;

  Directory get directory => _self;

  File get kongEntrypointSh => File(p.join(_self.path, 'kong-entrypoint.sh'));
}

/// Written by hand: everything the framework renders rather than reads.
class ScribeTemplates {
  ScribeTemplates(Directory parent) : _self = Directory(p.join(parent.path, 'templates'));

  final Directory _self;

  Directory get directory => _self;

  ScribeTemplatesOps get ops => ScribeTemplatesOps(_self);
}

class ScribeTemplatesOps {
  ScribeTemplatesOps(Directory parent) : _self = Directory(p.join(parent.path, 'ops'));

  final Directory _self;

  Directory get directory => _self;

  ScribeTemplatesOpsDocker get docker => ScribeTemplatesOpsDocker(_self);

  ScribeTemplatesOpsGateway get gateway => ScribeTemplatesOpsGateway(_self);
}

class ScribeTemplatesOpsDocker {
  ScribeTemplatesOpsDocker(Directory parent) : _self = Directory(p.join(parent.path, 'docker'));

  final Directory _self;

  Directory get directory => _self;

  File get dockerComposeYaml => File(p.join(_self.path, 'docker-compose.yaml'));

  File get resourcesYaml => File(p.join(_self.path, 'resources.yaml'));

  File get replicasYaml => File(p.join(_self.path, 'replicas.yaml'));

  File get tuningYaml => File(p.join(_self.path, 'tuning.yaml'));
}

class ScribeTemplatesOpsGateway {
  ScribeTemplatesOpsGateway(Directory parent) : _self = Directory(p.join(parent.path, 'gateway'));

  final Directory _self;

  Directory get directory => _self;

  File get kongYml => File(p.join(_self.path, 'kong.yml'));
}

class HostCore {
  HostCore(Directory parent) : _self = Directory(p.join(parent.path, 'core'));

  final Directory _self;

  Directory get directory => _self;

  HostCoreLint get lint => HostCoreLint(_self);

  CalebContracts get contracts => CalebContracts(_self);

  CalebDb get db => CalebDb(_self);
}

/// Ecrit a la main : l'arbre genere date d'avant l'extraction du package
/// `caleb`, et decrit encore `scribe/contracts/`, qui n'existe plus.
class CalebContracts {
  CalebContracts(Directory parent) : _self = Directory(p.join(parent.path, 'contracts'));

  final Directory _self;

  Directory get directory => _self;

  File get enumsTs => File(p.join(_self.path, 'enums.ts'));
}

class ScribePostgres {
  ScribePostgres(Directory parent) : _self = Directory(p.join(parent.path, 'postgres'));

  final Directory _self;

  Directory get directory => _self;
}

class CalebDb {
  CalebDb(Directory parent) : _self = Directory(p.join(parent.path, 'db'));

  final Directory _self;

  Directory get directory => _self;

  CalebDbProvisioning get provisioning => CalebDbProvisioning(_self);

  FoundationDbInit get init => FoundationDbInit(_self);

  FoundationDbMigrations get migrations => FoundationDbMigrations(_self);
}

class CalebDbProvisioning {
  CalebDbProvisioning(Directory parent) : _self = Directory(p.join(parent.path, 'provisioning'));

  final Directory _self;

  Directory get directory => _self;

  File get supabaseSql => File(p.join(_self.path, '_supabase.sql'));

  File get authOwnerSql => File(p.join(_self.path, 'auth-owner.sql'));

  File get gorseSql => File(p.join(_self.path, 'gorse.sql'));

  File get jwtSql => File(p.join(_self.path, 'jwt.sql'));

  File get logsSql => File(p.join(_self.path, 'logs.sql'));

  File get realtimeSql => File(p.join(_self.path, 'realtime.sql'));

  File get rolesSql => File(p.join(_self.path, 'roles.sql'));

  File get storageInitSql => File(p.join(_self.path, 'storage-init.sql'));

  File get webhooksSql => File(p.join(_self.path, 'webhooks.sql'));
}

class FoundationDbInit {
  FoundationDbInit(Directory parent) : _self = Directory(p.join(parent.path, 'init'));

  final Directory _self;

  Directory get directory => _self;

  File get devInitSql => File(p.join(_self.path, 'dev_init.sql'));

  File get realtimeSql => File(p.join(_self.path, 'realtime.sql'));

  FoundationDbInit00Setup get f00Setup => FoundationDbInit00Setup(_self);

  FoundationDbInit01EnumsTypes get f01EnumsTypes => FoundationDbInit01EnumsTypes(_self);

  FoundationDbInit02OtpPendingTokens get f02OtpPendingTokens => FoundationDbInit02OtpPendingTokens(_self);

  FoundationDbInit03Users get f03Users => FoundationDbInit03Users(_self);

  FoundationDbInit04Features get f04Features => FoundationDbInit04Features(_self);
}

class FoundationDbInit00Setup {
  FoundationDbInit00Setup(Directory parent) : _self = Directory(p.join(parent.path, '00_setup'));

  final Directory _self;

  Directory get directory => _self;

  File get f01SetupSql => File(p.join(_self.path, '01_setup.sql'));
}

class FoundationDbInit01EnumsTypes {
  FoundationDbInit01EnumsTypes(Directory parent) : _self = Directory(p.join(parent.path, '01_enums_types'));

  final Directory _self;

  Directory get directory => _self;

  File get f01EnumsSql => File(p.join(_self.path, '01_enums.sql'));

  File get f02TypesSql => File(p.join(_self.path, '02_types.sql'));
}

class FoundationDbInit02OtpPendingTokens {
  FoundationDbInit02OtpPendingTokens(Directory parent) : _self = Directory(p.join(parent.path, '02_otp_pending_tokens'));

  final Directory _self;

  Directory get directory => _self;

  File get f01OtpPendingTokensSql => File(p.join(_self.path, '01_otp_pending_tokens.sql'));
}

class FoundationDbInit03Users {
  FoundationDbInit03Users(Directory parent) : _self = Directory(p.join(parent.path, '03_users'));

  final Directory _self;

  Directory get directory => _self;

  FoundationDbInit03Users01AdminUsers get f01AdminUsers => FoundationDbInit03Users01AdminUsers(_self);

  FoundationDbInit03Users02AppUsers get f02AppUsers => FoundationDbInit03Users02AppUsers(_self);
}

class FoundationDbInit03Users01AdminUsers {
  FoundationDbInit03Users01AdminUsers(Directory parent) : _self = Directory(p.join(parent.path, '01_admin_users'));

  final Directory _self;

  Directory get directory => _self;

  File get f01RbacSql => File(p.join(_self.path, '01_rbac.sql'));

  File get f02AdminUsersSql => File(p.join(_self.path, '02_admin_users.sql'));

  File get f03ProfilesSql => File(p.join(_self.path, '03_profiles.sql'));

  File get f05SettingsSql => File(p.join(_self.path, '05_settings.sql'));

  File get f06DevicesSql => File(p.join(_self.path, '06_devices.sql'));

  File get f07VpnsSql => File(p.join(_self.path, '07_vpns.sql'));
}

class FoundationDbInit03Users02AppUsers {
  FoundationDbInit03Users02AppUsers(Directory parent) : _self = Directory(p.join(parent.path, '02_app_users'));

  final Directory _self;

  Directory get directory => _self;

  File get f01UsersSql => File(p.join(_self.path, '01_users.sql'));

  File get f03SettingsSql => File(p.join(_self.path, '03_settings.sql'));

  File get f05DevicesSql => File(p.join(_self.path, '05_devices.sql'));

  File get f06LastSignInSql => File(p.join(_self.path, '06_last_sign_in.sql'));
}

class FoundationDbInit04Features {
  FoundationDbInit04Features(Directory parent) : _self = Directory(p.join(parent.path, '04_features'));

  final Directory _self;

  Directory get directory => _self;

  FoundationDbInit04Features01Messaging get f01Messaging => FoundationDbInit04Features01Messaging(_self);

  FoundationDbInit04Features02Devops get f02Devops => FoundationDbInit04Features02Devops(_self);

  FoundationDbInit04Features03Analytics get f03Analytics => FoundationDbInit04Features03Analytics(_self);
}

class FoundationDbInit04Features01Messaging {
  FoundationDbInit04Features01Messaging(Directory parent) : _self = Directory(p.join(parent.path, '01_messaging'));

  final Directory _self;

  Directory get directory => _self;

  File get f00CampaignFiltersSql => File(p.join(_self.path, '00_campaign_filters.sql'));

  FoundationDbInit04Features01Messaging01Mails get f01Mails => FoundationDbInit04Features01Messaging01Mails(_self);

  FoundationDbInit04Features01Messaging02InAppNotifications get f02InAppNotifications => FoundationDbInit04Features01Messaging02InAppNotifications(_self);

  FoundationDbInit04Features01Messaging03NotificationPushes get f03NotificationPushes => FoundationDbInit04Features01Messaging03NotificationPushes(_self);
}

class FoundationDbInit04Features01Messaging01Mails {
  FoundationDbInit04Features01Messaging01Mails(Directory parent) : _self = Directory(p.join(parent.path, '01_mails'));

  final Directory _self;

  Directory get directory => _self;

  File get f01EmailTemplatesSql => File(p.join(_self.path, '01_email_templates.sql'));

  File get f02MailsSql => File(p.join(_self.path, '02_mails.sql'));

  File get f03MailStatisticsSql => File(p.join(_self.path, '03_mail_statistics.sql'));

  File get f04CampaignsSql => File(p.join(_self.path, '04_campaigns.sql'));
}

class FoundationDbInit04Features01Messaging02InAppNotifications {
  FoundationDbInit04Features01Messaging02InAppNotifications(Directory parent) : _self = Directory(p.join(parent.path, '02_in_app_notifications'));

  final Directory _self;

  Directory get directory => _self;

  File get f00InAppNotificationTemplatesSql => File(p.join(_self.path, '00_in_app_notification_templates.sql'));

  File get f01InAppNotificationsSql => File(p.join(_self.path, '01_in_app_notifications.sql'));

  File get f02InAppNotificationReadsSql => File(p.join(_self.path, '02_in_app_notification_reads.sql'));

  File get f03InAppNotificationOpensSql => File(p.join(_self.path, '03_in_app_notification_opens.sql'));

  File get f04InAppNotificationCampaignsSql => File(p.join(_self.path, '04_in_app_notification_campaigns.sql'));
}

class FoundationDbInit04Features01Messaging03NotificationPushes {
  FoundationDbInit04Features01Messaging03NotificationPushes(Directory parent) : _self = Directory(p.join(parent.path, '03_notification_pushes'));

  final Directory _self;

  Directory get directory => _self;

  File get f00PushTemplatesSql => File(p.join(_self.path, '00_push_templates.sql'));

  File get f01NotificationPushesSql => File(p.join(_self.path, '01_notification_pushes.sql'));

  File get f02NotificationPushOpensSql => File(p.join(_self.path, '02_notification_push_opens.sql'));

  File get f03PushCampaignsSql => File(p.join(_self.path, '03_push_campaigns.sql'));
}

class FoundationDbInit04Features02Devops {
  FoundationDbInit04Features02Devops(Directory parent) : _self = Directory(p.join(parent.path, '02_devops'));

  final Directory _self;

  Directory get directory => _self;

  FoundationDbInit04Features02Devops01DynamicLinks get f01DynamicLinks => FoundationDbInit04Features02Devops01DynamicLinks(_self);

  FoundationDbInit04Features02Devops02RemoteConfigs get f02RemoteConfigs => FoundationDbInit04Features02Devops02RemoteConfigs(_self);
}

class FoundationDbInit04Features02Devops01DynamicLinks {
  FoundationDbInit04Features02Devops01DynamicLinks(Directory parent) : _self = Directory(p.join(parent.path, '01_dynamic_links'));

  final Directory _self;

  Directory get directory => _self;

  File get f01DynamicLinksSql => File(p.join(_self.path, '01_dynamic_links.sql'));

  File get f02DynamicLinkStatisticsSql => File(p.join(_self.path, '02_dynamic_link_statistics.sql'));
}

class FoundationDbInit04Features02Devops02RemoteConfigs {
  FoundationDbInit04Features02Devops02RemoteConfigs(Directory parent) : _self = Directory(p.join(parent.path, '02_remote_configs'));

  final Directory _self;

  Directory get directory => _self;

  File get f01RemoteConfigsSql => File(p.join(_self.path, '01_remote_configs.sql'));

  File get f02RemoteConfigStatisticsSql => File(p.join(_self.path, '02_remote_config_statistics.sql'));
}

class FoundationDbInit04Features03Analytics {
  FoundationDbInit04Features03Analytics(Directory parent) : _self = Directory(p.join(parent.path, '03_analytics'));

  final Directory _self;

  Directory get directory => _self;

  File get f01IssuesSql => File(p.join(_self.path, '01_issues.sql'));

  File get f02FeedbackSql => File(p.join(_self.path, '02_feedback.sql'));

  File get f03ResponsesSql => File(p.join(_self.path, '03_responses.sql'));
}

class FoundationDbMigrations {
  FoundationDbMigrations(Directory parent) : _self = Directory(p.join(parent.path, 'migrations'));

  final Directory _self;

  Directory get directory => _self;
}

/// Written by hand: `host/packages/` is a submodule, so a checkout without
/// `--recurse-submodules` has nothing here for the scan to have found.
class HostPackages {
  HostPackages(Directory parent) : _self = Directory(p.join(parent.path, 'packages'));

  final Directory _self;

  Directory get directory => _self;
}

class Host {
  Host(Directory parent) : _self = Directory(p.join(parent.path, 'host'));

  final Directory _self;

  Directory get directory => _self;

  File get denoJson => File(p.join(_self.path, 'deno.json'));

  File get denoLock => File(p.join(_self.path, 'deno.lock'));

  File get envTs => File(p.join(_self.path, 'env.ts'));

  HostCore get core => HostCore(_self);

  HostPackages get packages => HostPackages(_self);

  FoundationFunctionsApi get api => FoundationFunctionsApi(_self);

  FoundationFunctionsDependencies get dependencies => FoundationFunctionsDependencies(_self);

  FoundationFunctionsContracts get contracts => FoundationFunctionsContracts(_self);

  FoundationFunctionsRuntime get runtime => FoundationFunctionsRuntime(_self);

  HostBoot get boot => HostBoot(_self);

  FoundationFunctionsKernel get kernel => FoundationFunctionsKernel(_self);

  FoundationFunctionsTests get tests => FoundationFunctionsTests(_self);
}

class FoundationFunctionsApi {
  FoundationFunctionsApi(Directory parent) : _self = Directory(p.join(parent.path, 'api'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiPublic get public => FoundationFunctionsApiPublic(_self);

  FoundationFunctionsApiInternal get internal => FoundationFunctionsApiInternal(_self);
}

class FoundationFunctionsApiPublic {
  FoundationFunctionsApiPublic(Directory parent) : _self = Directory(p.join(parent.path, 'public'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiPublicAdmin get admin => FoundationFunctionsApiPublicAdmin(_self);

  FoundationFunctionsApiPublicApp get app => FoundationFunctionsApiPublicApp(_self);
}

class FoundationFunctionsApiPublicAdmin {
  FoundationFunctionsApiPublicAdmin(Directory parent) : _self = Directory(p.join(parent.path, 'admin'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  File get middlewareTs => File(p.join(_self.path, 'middleware.ts'));

  FoundationFunctionsApiPublicAdminSrc get src => FoundationFunctionsApiPublicAdminSrc(_self);
}

class FoundationFunctionsApiPublicAdminSrc {
  FoundationFunctionsApiPublicAdminSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiPublicAdminSrcAuth get auth => FoundationFunctionsApiPublicAdminSrcAuth(_self);

  FoundationFunctionsApiPublicAdminSrcRole get role => FoundationFunctionsApiPublicAdminSrcRole(_self);

  FoundationFunctionsApiPublicAdminSrcTeam get team => FoundationFunctionsApiPublicAdminSrcTeam(_self);

  FoundationFunctionsApiPublicAdminSrcUser get user => FoundationFunctionsApiPublicAdminSrcUser(_self);

  FoundationFunctionsApiPublicAdminSrcVpn get vpn => FoundationFunctionsApiPublicAdminSrcVpn(_self);
}

class FoundationFunctionsApiPublicAdminSrcAuth {
  FoundationFunctionsApiPublicAdminSrcAuth(Directory parent) : _self = Directory(p.join(parent.path, 'auth'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAdminSrcAuthSignIn get signIn => FoundationFunctionsApiPublicAdminSrcAuthSignIn(_self);

  FoundationFunctionsApiPublicAdminSrcAuthUser get user => FoundationFunctionsApiPublicAdminSrcAuthUser(_self);
}

class FoundationFunctionsApiPublicAdminSrcAuthSignIn {
  FoundationFunctionsApiPublicAdminSrcAuthSignIn(Directory parent) : _self = Directory(p.join(parent.path, 'sign-in'));

  final Directory _self;

  Directory get directory => _self;

  File get resendOtpTs => File(p.join(_self.path, 'resend-otp.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get verifyOtpTs => File(p.join(_self.path, 'verify-otp.ts'));

  File get withEmailAndPasswordTs => File(p.join(_self.path, 'with-email-and-password.ts'));
}

class FoundationFunctionsApiPublicAdminSrcAuthUser {
  FoundationFunctionsApiPublicAdminSrcAuthUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get currentTs => File(p.join(_self.path, 'current.ts'));

  File get permissionsTs => File(p.join(_self.path, 'permissions.ts'));

  File get recoverSessionTs => File(p.join(_self.path, 'recover-session.ts'));

  File get refreshSessionTs => File(p.join(_self.path, 'refresh-session.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get signOutTs => File(p.join(_self.path, 'sign-out.ts'));

  File get updatePasswordTs => File(p.join(_self.path, 'update-password.ts'));
}

class FoundationFunctionsApiPublicAdminSrcRole {
  FoundationFunctionsApiPublicAdminSrcRole(Directory parent) : _self = Directory(p.join(parent.path, 'role'));

  final Directory _self;

  Directory get directory => _self;

  File get createTs => File(p.join(_self.path, 'create.ts'));

  File get deleteTs => File(p.join(_self.path, 'delete.ts'));

  File get paginationTs => File(p.join(_self.path, 'pagination.ts'));

  File get readTs => File(p.join(_self.path, 'read.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateTs => File(p.join(_self.path, 'update.ts'));
}

class FoundationFunctionsApiPublicAdminSrcTeam {
  FoundationFunctionsApiPublicAdminSrcTeam(Directory parent) : _self = Directory(p.join(parent.path, 'team'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAdminSrcTeamMember get member => FoundationFunctionsApiPublicAdminSrcTeamMember(_self);

  FoundationFunctionsApiPublicAdminSrcTeamMembers get members => FoundationFunctionsApiPublicAdminSrcTeamMembers(_self);
}

class FoundationFunctionsApiPublicAdminSrcTeamMember {
  FoundationFunctionsApiPublicAdminSrcTeamMember(Directory parent) : _self = Directory(p.join(parent.path, 'member'));

  final Directory _self;

  Directory get directory => _self;

  File get createTs => File(p.join(_self.path, 'create.ts'));

  File get deleteTs => File(p.join(_self.path, 'delete.ts'));

  File get readTs => File(p.join(_self.path, 'read.ts'));

  File get renewVpnTs => File(p.join(_self.path, 'renew-vpn.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAdminSrcTeamMemberUpdate get update => FoundationFunctionsApiPublicAdminSrcTeamMemberUpdate(_self);
}

class FoundationFunctionsApiPublicAdminSrcTeamMemberUpdate {
  FoundationFunctionsApiPublicAdminSrcTeamMemberUpdate(Directory parent) : _self = Directory(p.join(parent.path, 'update'));

  final Directory _self;

  Directory get directory => _self;

  File get birthdayTs => File(p.join(_self.path, 'birthday.ts'));

  File get firstnameTs => File(p.join(_self.path, 'firstname.ts'));

  File get genderTs => File(p.join(_self.path, 'gender.ts'));

  File get lastnameTs => File(p.join(_self.path, 'lastname.ts'));

  File get passwordTs => File(p.join(_self.path, 'password.ts'));

  File get phoneTs => File(p.join(_self.path, 'phone.ts'));

  File get roleTs => File(p.join(_self.path, 'role.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiPublicAdminSrcTeamMembers {
  FoundationFunctionsApiPublicAdminSrcTeamMembers(Directory parent) : _self = Directory(p.join(parent.path, 'members'));

  final Directory _self;

  Directory get directory => _self;

  File get paginationTs => File(p.join(_self.path, 'pagination.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiPublicAdminSrcUser {
  FoundationFunctionsApiPublicAdminSrcUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAdminSrcUserAccount get account => FoundationFunctionsApiPublicAdminSrcUserAccount(_self);

  FoundationFunctionsApiPublicAdminSrcUserVpn get vpn => FoundationFunctionsApiPublicAdminSrcUserVpn(_self);
}

class FoundationFunctionsApiPublicAdminSrcUserAccount {
  FoundationFunctionsApiPublicAdminSrcUserAccount(Directory parent) : _self = Directory(p.join(parent.path, 'account'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAdminSrcUserAccountAvatar get avatar => FoundationFunctionsApiPublicAdminSrcUserAccountAvatar(_self);
}

class FoundationFunctionsApiPublicAdminSrcUserAccountAvatar {
  FoundationFunctionsApiPublicAdminSrcUserAccountAvatar(Directory parent) : _self = Directory(p.join(parent.path, 'avatar'));

  final Directory _self;

  Directory get directory => _self;

  File get deleteTs => File(p.join(_self.path, 'delete.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateTs => File(p.join(_self.path, 'update.ts'));
}

class FoundationFunctionsApiPublicAdminSrcUserVpn {
  FoundationFunctionsApiPublicAdminSrcUserVpn(Directory parent) : _self = Directory(p.join(parent.path, 'vpn'));

  final Directory _self;

  Directory get directory => _self;

  File get downloadTs => File(p.join(_self.path, 'download.ts'));

  File get renewTs => File(p.join(_self.path, 'renew.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiPublicAdminSrcVpn {
  FoundationFunctionsApiPublicAdminSrcVpn(Directory parent) : _self = Directory(p.join(parent.path, 'vpn'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get vpnTs => File(p.join(_self.path, 'vpn.ts'));
}

class FoundationFunctionsApiPublicApp {
  FoundationFunctionsApiPublicApp(Directory parent) : _self = Directory(p.join(parent.path, 'app'));

  final Directory _self;

  Directory get directory => _self;

  File get countryFirewallTs => File(p.join(_self.path, '_country_firewall.ts'));

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  File get middlewareTs => File(p.join(_self.path, 'middleware.ts'));

  FoundationFunctionsApiPublicAppSrc get src => FoundationFunctionsApiPublicAppSrc(_self);
}

class FoundationFunctionsApiPublicAppSrc {
  FoundationFunctionsApiPublicAppSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiPublicAppSrcAuth get auth => FoundationFunctionsApiPublicAppSrcAuth(_self);

  FoundationFunctionsApiPublicAppSrcUser get user => FoundationFunctionsApiPublicAppSrcUser(_self);
}

class FoundationFunctionsApiPublicAppSrcAuth {
  FoundationFunctionsApiPublicAppSrcAuth(Directory parent) : _self = Directory(p.join(parent.path, 'auth'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAppSrcAuthForgotPassword get forgotPassword => FoundationFunctionsApiPublicAppSrcAuthForgotPassword(_self);

  FoundationFunctionsApiPublicAppSrcAuthSignIn get signIn => FoundationFunctionsApiPublicAppSrcAuthSignIn(_self);

  FoundationFunctionsApiPublicAppSrcAuthSignUp get signUp => FoundationFunctionsApiPublicAppSrcAuthSignUp(_self);

  FoundationFunctionsApiPublicAppSrcAuthUser get user => FoundationFunctionsApiPublicAppSrcAuthUser(_self);
}

class FoundationFunctionsApiPublicAppSrcAuthForgotPassword {
  FoundationFunctionsApiPublicAppSrcAuthForgotPassword(Directory parent) : _self = Directory(p.join(parent.path, 'forgot-password'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get withEmailTs => File(p.join(_self.path, 'with-email.ts'));
}

class FoundationFunctionsApiPublicAppSrcAuthSignIn {
  FoundationFunctionsApiPublicAppSrcAuthSignIn(Directory parent) : _self = Directory(p.join(parent.path, 'sign-in'));

  final Directory _self;

  Directory get directory => _self;

  File get resendOtpTs => File(p.join(_self.path, 'resend-otp.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get verifyOtpTs => File(p.join(_self.path, 'verify-otp.ts'));

  File get withEmailAndPasswordTs => File(p.join(_self.path, 'with-email-and-password.ts'));
}

class FoundationFunctionsApiPublicAppSrcAuthSignUp {
  FoundationFunctionsApiPublicAppSrcAuthSignUp(Directory parent) : _self = Directory(p.join(parent.path, 'sign-up'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get withAppleTs => File(p.join(_self.path, 'with-apple.ts'));

  File get withEmailAndPasswordTs => File(p.join(_self.path, 'with-email-and-password.ts'));

  File get withGoogleTs => File(p.join(_self.path, 'with-google.ts'));

  File get withPhoneTs => File(p.join(_self.path, 'with-phone.ts'));
}

class FoundationFunctionsApiPublicAppSrcAuthUser {
  FoundationFunctionsApiPublicAppSrcAuthUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get deleteAccountTs => File(p.join(_self.path, 'delete-account.ts'));

  File get getTs => File(p.join(_self.path, 'get.ts'));

  File get recoverSessionTs => File(p.join(_self.path, 'recover-session.ts'));

  File get refreshSessionTs => File(p.join(_self.path, 'refresh-session.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get signOutTs => File(p.join(_self.path, 'sign-out.ts'));

  File get updatePasswordTs => File(p.join(_self.path, 'update-password.ts'));
}

class FoundationFunctionsApiPublicAppSrcUser {
  FoundationFunctionsApiPublicAppSrcUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get lastKnowPositionTs => File(p.join(_self.path, 'last-know-position.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiPublicAppSrcUserAccount get account => FoundationFunctionsApiPublicAppSrcUserAccount(_self);

  FoundationFunctionsApiPublicAppSrcUserPreferences get preferences => FoundationFunctionsApiPublicAppSrcUserPreferences(_self);

  FoundationFunctionsApiPublicAppSrcUserSupport get support => FoundationFunctionsApiPublicAppSrcUserSupport(_self);
}

class FoundationFunctionsApiPublicAppSrcUserAccount {
  FoundationFunctionsApiPublicAppSrcUserAccount(Directory parent) : _self = Directory(p.join(parent.path, 'account'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateAvatarTs => File(p.join(_self.path, 'update-avatar.ts'));

  File get updateFirstnameTs => File(p.join(_self.path, 'update-firstname.ts'));

  File get updateLastnameTs => File(p.join(_self.path, 'update-lastname.ts'));

  File get updatePhoneTs => File(p.join(_self.path, 'update-phone.ts'));

  File get updatePreferredNameTs => File(p.join(_self.path, 'update-preferred-name.ts'));

  File get updateUsePreferredNameTs => File(p.join(_self.path, 'update-use-preferred-name.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserPreferences {
  FoundationFunctionsApiPublicAppSrcUserPreferences(Directory parent) : _self = Directory(p.join(parent.path, 'preferences'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateDistrictsTs => File(p.join(_self.path, 'update-districts.ts'));

  File get updateThemesTs => File(p.join(_self.path, 'update-themes.ts'));

  FoundationFunctionsApiPublicAppSrcUserPreferencesAppearance get appearance => FoundationFunctionsApiPublicAppSrcUserPreferencesAppearance(_self);

  FoundationFunctionsApiPublicAppSrcUserPreferencesCity get city => FoundationFunctionsApiPublicAppSrcUserPreferencesCity(_self);

  FoundationFunctionsApiPublicAppSrcUserPreferencesLocalization get localization => FoundationFunctionsApiPublicAppSrcUserPreferencesLocalization(_self);

  FoundationFunctionsApiPublicAppSrcUserPreferencesNotifications get notifications => FoundationFunctionsApiPublicAppSrcUserPreferencesNotifications(_self);
}

class FoundationFunctionsApiPublicAppSrcUserPreferencesAppearance {
  FoundationFunctionsApiPublicAppSrcUserPreferencesAppearance(Directory parent) : _self = Directory(p.join(parent.path, 'appearance'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateThemeModeTs => File(p.join(_self.path, 'update-theme-mode.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserPreferencesCity {
  FoundationFunctionsApiPublicAppSrcUserPreferencesCity(Directory parent) : _self = Directory(p.join(parent.path, 'city'));

  final Directory _self;

  Directory get directory => _self;

  File get activeTs => File(p.join(_self.path, 'active.ts'));

  File get addTs => File(p.join(_self.path, 'add.ts'));

  File get deleteTs => File(p.join(_self.path, 'delete.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserPreferencesLocalization {
  FoundationFunctionsApiPublicAppSrcUserPreferencesLocalization(Directory parent) : _self = Directory(p.join(parent.path, 'localization'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateLocalizationTs => File(p.join(_self.path, 'update-localization.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserPreferencesNotifications {
  FoundationFunctionsApiPublicAppSrcUserPreferencesNotifications(Directory parent) : _self = Directory(p.join(parent.path, 'notifications'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateDisplayTs => File(p.join(_self.path, 'update-display.ts'));

  File get updateRemindersTs => File(p.join(_self.path, 'update-reminders.ts'));

  File get updateSoundTs => File(p.join(_self.path, 'update-sound.ts'));

  File get updateVibrationsTs => File(p.join(_self.path, 'update-vibrations.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserSupport {
  FoundationFunctionsApiPublicAppSrcUserSupport(Directory parent) : _self = Directory(p.join(parent.path, 'support'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get updateShakeReportTs => File(p.join(_self.path, 'update-shake-report.ts'));

  FoundationFunctionsApiPublicAppSrcUserSupportFeedback get feedback => FoundationFunctionsApiPublicAppSrcUserSupportFeedback(_self);

  FoundationFunctionsApiPublicAppSrcUserSupportIssue get issue => FoundationFunctionsApiPublicAppSrcUserSupportIssue(_self);
}

class FoundationFunctionsApiPublicAppSrcUserSupportFeedback {
  FoundationFunctionsApiPublicAppSrcUserSupportFeedback(Directory parent) : _self = Directory(p.join(parent.path, 'feedback'));

  final Directory _self;

  Directory get directory => _self;

  File get addTs => File(p.join(_self.path, 'add.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiPublicAppSrcUserSupportIssue {
  FoundationFunctionsApiPublicAppSrcUserSupportIssue(Directory parent) : _self = Directory(p.join(parent.path, 'issue'));

  final Directory _self;

  Directory get directory => _self;

  File get addTs => File(p.join(_self.path, 'add.ts'));

  File get paginationTs => File(p.join(_self.path, 'pagination.ts'));

  File get removeTs => File(p.join(_self.path, 'remove.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));
}

class FoundationFunctionsApiInternal {
  FoundationFunctionsApiInternal(Directory parent) : _self = Directory(p.join(parent.path, 'internal'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalAuth get auth => FoundationFunctionsApiInternalAuth(_self);

  FoundationFunctionsApiInternalHooks get hooks => FoundationFunctionsApiInternalHooks(_self);

  FoundationFunctionsApiInternalHtml get html => FoundationFunctionsApiInternalHtml(_self);

  FoundationFunctionsApiInternalQueue get queue => FoundationFunctionsApiInternalQueue(_self);

  FoundationFunctionsApiInternalSearcher get searcher => FoundationFunctionsApiInternalSearcher(_self);

  FoundationFunctionsApiInternalVpn get vpn => FoundationFunctionsApiInternalVpn(_self);
}

class FoundationFunctionsApiInternalAuth {
  FoundationFunctionsApiInternalAuth(Directory parent) : _self = Directory(p.join(parent.path, 'auth'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalAuthIntra get intra => FoundationFunctionsApiInternalAuthIntra(_self);
}

class FoundationFunctionsApiInternalAuthIntra {
  FoundationFunctionsApiInternalAuthIntra(Directory parent) : _self = Directory(p.join(parent.path, 'intra'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalAuthIntraSrc get src => FoundationFunctionsApiInternalAuthIntraSrc(_self);
}

class FoundationFunctionsApiInternalAuthIntraSrc {
  FoundationFunctionsApiInternalAuthIntraSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooks {
  FoundationFunctionsApiInternalHooks(Directory parent) : _self = Directory(p.join(parent.path, 'hooks'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalHooksCustomAccessToken get customAccessToken => FoundationFunctionsApiInternalHooksCustomAccessToken(_self);

  FoundationFunctionsApiInternalHooksEmail get email => FoundationFunctionsApiInternalHooksEmail(_self);

  FoundationFunctionsApiInternalHooksPush get push => FoundationFunctionsApiInternalHooksPush(_self);

  FoundationFunctionsApiInternalHooksSms get sms => FoundationFunctionsApiInternalHooksSms(_self);
}

class FoundationFunctionsApiInternalHooksCustomAccessToken {
  FoundationFunctionsApiInternalHooksCustomAccessToken(Directory parent) : _self = Directory(p.join(parent.path, 'custom-access-token'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiInternalHooksCustomAccessTokenSrc get src => FoundationFunctionsApiInternalHooksCustomAccessTokenSrc(_self);
}

class FoundationFunctionsApiInternalHooksCustomAccessTokenSrc {
  FoundationFunctionsApiInternalHooksCustomAccessTokenSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalHooksCustomAccessTokenSrcHook get hook => FoundationFunctionsApiInternalHooksCustomAccessTokenSrcHook(_self);
}

class FoundationFunctionsApiInternalHooksCustomAccessTokenSrcHook {
  FoundationFunctionsApiInternalHooksCustomAccessTokenSrcHook(Directory parent) : _self = Directory(p.join(parent.path, 'hook'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksEmail {
  FoundationFunctionsApiInternalHooksEmail(Directory parent) : _self = Directory(p.join(parent.path, 'email'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiInternalHooksEmailSrc get src => FoundationFunctionsApiInternalHooksEmailSrc(_self);
}

class FoundationFunctionsApiInternalHooksEmailSrc {
  FoundationFunctionsApiInternalHooksEmailSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get renderersTs => File(p.join(_self.path, '_renderers.ts'));

  FoundationFunctionsApiInternalHooksEmailSrcCampaignRun get campaignRun => FoundationFunctionsApiInternalHooksEmailSrcCampaignRun(_self);

  FoundationFunctionsApiInternalHooksEmailSrcCreate get create => FoundationFunctionsApiInternalHooksEmailSrcCreate(_self);

  FoundationFunctionsApiInternalHooksEmailSrcGotrue get gotrue => FoundationFunctionsApiInternalHooksEmailSrcGotrue(_self);

  FoundationFunctionsApiInternalHooksEmailSrcHook get hook => FoundationFunctionsApiInternalHooksEmailSrcHook(_self);

  FoundationFunctionsApiInternalHooksEmailSrcOpen get open => FoundationFunctionsApiInternalHooksEmailSrcOpen(_self);

  FoundationFunctionsApiInternalHooksEmailSrcSender get sender => FoundationFunctionsApiInternalHooksEmailSrcSender(_self);
}

class FoundationFunctionsApiInternalHooksEmailSrcCampaignRun {
  FoundationFunctionsApiInternalHooksEmailSrcCampaignRun(Directory parent) : _self = Directory(p.join(parent.path, 'campaign-run'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksEmailSrcCreate {
  FoundationFunctionsApiInternalHooksEmailSrcCreate(Directory parent) : _self = Directory(p.join(parent.path, 'create'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksEmailSrcGotrue {
  FoundationFunctionsApiInternalHooksEmailSrcGotrue(Directory parent) : _self = Directory(p.join(parent.path, 'gotrue'));

  final Directory _self;

  Directory get directory => _self;

  File get actionTs => File(p.join(_self.path, 'action.ts'));

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksEmailSrcHook {
  FoundationFunctionsApiInternalHooksEmailSrcHook(Directory parent) : _self = Directory(p.join(parent.path, 'hook'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksEmailSrcOpen {
  FoundationFunctionsApiInternalHooksEmailSrcOpen(Directory parent) : _self = Directory(p.join(parent.path, 'open'));

  final Directory _self;

  Directory get directory => _self;

  File get handlerTs => File(p.join(_self.path, 'handler.ts'));
}

class FoundationFunctionsApiInternalHooksEmailSrcSender {
  FoundationFunctionsApiInternalHooksEmailSrcSender(Directory parent) : _self = Directory(p.join(parent.path, 'sender'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksPush {
  FoundationFunctionsApiInternalHooksPush(Directory parent) : _self = Directory(p.join(parent.path, 'push'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiInternalHooksPushSrc get src => FoundationFunctionsApiInternalHooksPushSrc(_self);
}

class FoundationFunctionsApiInternalHooksPushSrc {
  FoundationFunctionsApiInternalHooksPushSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalHooksPushSrcSend get send => FoundationFunctionsApiInternalHooksPushSrcSend(_self);
}

class FoundationFunctionsApiInternalHooksPushSrcSend {
  FoundationFunctionsApiInternalHooksPushSrcSend(Directory parent) : _self = Directory(p.join(parent.path, 'send'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHooksSms {
  FoundationFunctionsApiInternalHooksSms(Directory parent) : _self = Directory(p.join(parent.path, 'sms'));

  final Directory _self;

  Directory get directory => _self;

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  FoundationFunctionsApiInternalHooksSmsSrc get src => FoundationFunctionsApiInternalHooksSmsSrc(_self);
}

class FoundationFunctionsApiInternalHooksSmsSrc {
  FoundationFunctionsApiInternalHooksSmsSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalHooksSmsSrcGotrue get gotrue => FoundationFunctionsApiInternalHooksSmsSrcGotrue(_self);
}

class FoundationFunctionsApiInternalHooksSmsSrcGotrue {
  FoundationFunctionsApiInternalHooksSmsSrcGotrue(Directory parent) : _self = Directory(p.join(parent.path, 'gotrue'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalHtml {
  FoundationFunctionsApiInternalHtml(Directory parent) : _self = Directory(p.join(parent.path, 'html'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalHtmlConfirm get confirm => FoundationFunctionsApiInternalHtmlConfirm(_self);
}

class FoundationFunctionsApiInternalHtmlConfirm {
  FoundationFunctionsApiInternalHtmlConfirm(Directory parent) : _self = Directory(p.join(parent.path, 'confirm'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalHtmlConfirmSrc get src => FoundationFunctionsApiInternalHtmlConfirmSrc(_self);
}

class FoundationFunctionsApiInternalHtmlConfirmSrc {
  FoundationFunctionsApiInternalHtmlConfirmSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get pageTsx => File(p.join(_self.path, 'page.tsx'));
}

class FoundationFunctionsApiInternalQueue {
  FoundationFunctionsApiInternalQueue(Directory parent) : _self = Directory(p.join(parent.path, 'queue'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalQueueDrain get drain => FoundationFunctionsApiInternalQueueDrain(_self);

  FoundationFunctionsApiInternalQueueHandlers get handlers => FoundationFunctionsApiInternalQueueHandlers(_self);
}

class FoundationFunctionsApiInternalQueueDrain {
  FoundationFunctionsApiInternalQueueDrain(Directory parent) : _self = Directory(p.join(parent.path, 'drain'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalQueueHandlers {
  FoundationFunctionsApiInternalQueueHandlers(Directory parent) : _self = Directory(p.join(parent.path, 'handlers'));

  final Directory _self;

  Directory get directory => _self;

  File get handlersTs => File(p.join(_self.path, 'handlers.ts'));

  File get logsTs => File(p.join(_self.path, 'logs.ts'));

  File get searcherSyncTs => File(p.join(_self.path, 'searcher-sync.ts'));
}

class FoundationFunctionsApiInternalSearcher {
  FoundationFunctionsApiInternalSearcher(Directory parent) : _self = Directory(p.join(parent.path, 'searcher'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalSearcherSrc get src => FoundationFunctionsApiInternalSearcherSrc(_self);
}

class FoundationFunctionsApiInternalSearcherSrc {
  FoundationFunctionsApiInternalSearcherSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsApiInternalSearcherSrcDrain get drain => FoundationFunctionsApiInternalSearcherSrcDrain(_self);

  FoundationFunctionsApiInternalSearcherSrcSetup get setup => FoundationFunctionsApiInternalSearcherSrcSetup(_self);

  FoundationFunctionsApiInternalSearcherSrcSync get sync => FoundationFunctionsApiInternalSearcherSrcSync(_self);
}

class FoundationFunctionsApiInternalSearcherSrcDrain {
  FoundationFunctionsApiInternalSearcherSrcDrain(Directory parent) : _self = Directory(p.join(parent.path, 'drain'));

  final Directory _self;

  Directory get directory => _self;
}

class FoundationFunctionsApiInternalSearcherSrcSetup {
  FoundationFunctionsApiInternalSearcherSrcSetup(Directory parent) : _self = Directory(p.join(parent.path, 'setup'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalSearcherSrcSync {
  FoundationFunctionsApiInternalSearcherSrcSync(Directory parent) : _self = Directory(p.join(parent.path, 'sync'));

  final Directory _self;

  Directory get directory => _self;

  File get endpointTs => File(p.join(_self.path, 'endpoint.ts'));
}

class FoundationFunctionsApiInternalVpn {
  FoundationFunctionsApiInternalVpn(Directory parent) : _self = Directory(p.join(parent.path, 'vpn'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationFunctionsApiInternalVpnSrc get src => FoundationFunctionsApiInternalVpnSrc(_self);
}

class FoundationFunctionsApiInternalVpnSrc {
  FoundationFunctionsApiInternalVpnSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get createTs => File(p.join(_self.path, 'create.ts'));

  File get deleteTs => File(p.join(_self.path, 'delete.ts'));

  File get expireTs => File(p.join(_self.path, 'expire.ts'));
}

class FoundationFunctionsContracts {
  FoundationFunctionsContracts(Directory parent) : _self = Directory(p.join(parent.path, 'contracts'));

  final Directory _self;

  Directory get directory => _self;

  File get accountTs => File(p.join(_self.path, 'account.ts'));

  File get enumsTs => File(p.join(_self.path, 'enums.ts'));

  File get paginationTs => File(p.join(_self.path, 'pagination.ts'));

  File get resultTs => File(p.join(_self.path, 'result.ts'));

  FoundationFunctionsContractsAdmin get admin => FoundationFunctionsContractsAdmin(_self);

  FoundationFunctionsContractsCommon get common => FoundationFunctionsContractsCommon(_self);

  FoundationFunctionsContractsEntity get entity => FoundationFunctionsContractsEntity(_self);

  FoundationFunctionsContractsUser get user => FoundationFunctionsContractsUser(_self);
}

class FoundationFunctionsContractsAdmin {
  FoundationFunctionsContractsAdmin(Directory parent) : _self = Directory(p.join(parent.path, 'admin'));

  final Directory _self;

  Directory get directory => _self;

  File get adminTs => File(p.join(_self.path, 'admin.ts'));

  File get previewTs => File(p.join(_self.path, 'preview.ts'));
}

class FoundationFunctionsContractsCommon {
  FoundationFunctionsContractsCommon(Directory parent) : _self = Directory(p.join(parent.path, 'common'));

  final Directory _self;

  Directory get directory => _self;

  File get addressTs => File(p.join(_self.path, 'address.ts'));

  File get avatarTs => File(p.join(_self.path, 'avatar.ts'));

  File get emailTs => File(p.join(_self.path, 'email.ts'));

  File get imageTs => File(p.join(_self.path, 'image.ts'));

  File get locationTs => File(p.join(_self.path, 'location.ts'));

  File get metadataTs => File(p.join(_self.path, 'metadata.ts'));

  File get namesTs => File(p.join(_self.path, 'names.ts'));

  File get phoneTs => File(p.join(_self.path, 'phone.ts'));

  File get timeTs => File(p.join(_self.path, 'time.ts'));
}

class FoundationFunctionsContractsEntity {
  FoundationFunctionsContractsEntity(Directory parent) : _self = Directory(p.join(parent.path, 'entity'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsContractsEntityBrand get brand => FoundationFunctionsContractsEntityBrand(_self);

  FoundationFunctionsContractsEntityStore get store => FoundationFunctionsContractsEntityStore(_self);
}

class FoundationFunctionsContractsEntityBrand {
  FoundationFunctionsContractsEntityBrand(Directory parent) : _self = Directory(p.join(parent.path, 'brand'));

  final Directory _self;

  Directory get directory => _self;

  File get fullTs => File(p.join(_self.path, 'full.ts'));

  File get previewTs => File(p.join(_self.path, 'preview.ts'));

  File get statsTs => File(p.join(_self.path, 'stats.ts'));
}

class FoundationFunctionsContractsEntityStore {
  FoundationFunctionsContractsEntityStore(Directory parent) : _self = Directory(p.join(parent.path, 'store'));

  final Directory _self;

  Directory get directory => _self;

  File get fullTs => File(p.join(_self.path, 'full.ts'));

  File get previewTs => File(p.join(_self.path, 'preview.ts'));

  File get statsTs => File(p.join(_self.path, 'stats.ts'));
}

class FoundationFunctionsContractsUser {
  FoundationFunctionsContractsUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get userTs => File(p.join(_self.path, 'user.ts'));
}

class FoundationFunctionsDependencies {
  FoundationFunctionsDependencies(Directory parent) : _self = Directory(p.join(parent.path, 'dependencies'));

  final Directory _self;

  Directory get directory => _self;

  File get clientsTs => File(p.join(_self.path, 'clients.ts'));

  FoundationFunctionsDependenciesDatabase get database => FoundationFunctionsDependenciesDatabase(_self);

  FoundationFunctionsDependenciesFeatures get features => FoundationFunctionsDependenciesFeatures(_self);

  FoundationFunctionsDependenciesGeospatial get geospatial => FoundationFunctionsDependenciesGeospatial(_self);

  FoundationFunctionsDependenciesSecurity get security => FoundationFunctionsDependenciesSecurity(_self);

  FoundationFunctionsRuntime get system => FoundationFunctionsRuntime(_self);
}

class FoundationFunctionsDependenciesDatabase {
  FoundationFunctionsDependenciesDatabase(Directory parent) : _self = Directory(p.join(parent.path, 'database'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsDependenciesDatabaseRealtime get realtime => FoundationFunctionsDependenciesDatabaseRealtime(_self);

  FoundationFunctionsDependenciesDatabaseRest get rest => FoundationFunctionsDependenciesDatabaseRest(_self);

  FoundationFunctionsDependenciesDatabaseStorage get storage => FoundationFunctionsDependenciesDatabaseStorage(_self);
}

class FoundationFunctionsDependenciesDatabaseRealtime {
  FoundationFunctionsDependenciesDatabaseRealtime(Directory parent) : _self = Directory(p.join(parent.path, 'realtime'));

  final Directory _self;

  Directory get directory => _self;

  File get deviceTs => File(p.join(_self.path, 'device.ts'));

  File get entityTs => File(p.join(_self.path, 'entity.ts'));

  File get eventTs => File(p.join(_self.path, 'event.ts'));

  File get realtimeTs => File(p.join(_self.path, 'realtime.ts'));

  FoundationFunctionsDependenciesDatabaseRealtimeInternal get internal => FoundationFunctionsDependenciesDatabaseRealtimeInternal(_self);
}

class FoundationFunctionsDependenciesDatabaseRealtimeInternal {
  FoundationFunctionsDependenciesDatabaseRealtimeInternal(Directory parent) : _self = Directory(p.join(parent.path, '_internal'));

  final Directory _self;

  Directory get directory => _self;

  File get emitterTs => File(p.join(_self.path, 'emitter.ts'));
}

class FoundationFunctionsDependenciesDatabaseRest {
  FoundationFunctionsDependenciesDatabaseRest(Directory parent) : _self = Directory(p.join(parent.path, 'rest'));

  final Directory _self;

  Directory get directory => _self;

  File get restTs => File(p.join(_self.path, 'rest.ts'));

  File get clientTs => File(p.join(_self.path, 'client.ts'));

  File get tablesTs => File(p.join(_self.path, 'tables.ts'));

  File get schemaTs => File(p.join(_self.path, 'schema.ts'));

  FoundationFunctionsDependenciesDatabaseRestSearcher get searcher => FoundationFunctionsDependenciesDatabaseRestSearcher(_self);

  FoundationFunctionsDependenciesDatabaseRestGen get gen => FoundationFunctionsDependenciesDatabaseRestGen(_self);
}

class FoundationFunctionsDependenciesDatabaseRestSearcher {
  FoundationFunctionsDependenciesDatabaseRestSearcher(Directory parent) : _self = Directory(p.join(parent.path, 'searcher'));

  final Directory _self;

  Directory get directory => _self;

  File get mappingFieldsTs => File(p.join(_self.path, '_mapping_fields.ts'));

  File get queryBuilderTs => File(p.join(_self.path, '_query_builder.ts'));

  File get queryFieldsTs => File(p.join(_self.path, '_query_fields.ts'));

  File get searchCacheTs => File(p.join(_self.path, '_search_cache.ts'));

  File get searchCacheKeyTs => File(p.join(_self.path, '_search_cache_key.ts'));

  File get clientTs => File(p.join(_self.path, 'client.ts'));

  File get entityTs => File(p.join(_self.path, 'entity.ts'));

  File get setupTs => File(p.join(_self.path, 'setup.ts'));

  File get typesTs => File(p.join(_self.path, 'types.ts'));

  FoundationFunctionsDependenciesDatabaseRestSearcherBrand get brand => FoundationFunctionsDependenciesDatabaseRestSearcherBrand(_self);

  FoundationFunctionsDependenciesDatabaseRestSearcherStore get store => FoundationFunctionsDependenciesDatabaseRestSearcherStore(_self);
}

class FoundationFunctionsDependenciesDatabaseRestSearcherBrand {
  FoundationFunctionsDependenciesDatabaseRestSearcherBrand(Directory parent) : _self = Directory(p.join(parent.path, 'brand'));

  final Directory _self;

  Directory get directory => _self;

  File get brandTs => File(p.join(_self.path, 'brand.ts'));
}

class FoundationFunctionsDependenciesDatabaseRestSearcherStore {
  FoundationFunctionsDependenciesDatabaseRestSearcherStore(Directory parent) : _self = Directory(p.join(parent.path, 'store'));

  final Directory _self;

  Directory get directory => _self;

  File get storeTs => File(p.join(_self.path, 'store.ts'));
}

class FoundationFunctionsDependenciesDatabaseRestGen {
  FoundationFunctionsDependenciesDatabaseRestGen(Directory parent) : _self = Directory(p.join(parent.path, 'gen'));

  final Directory _self;

  Directory get directory => _self;

  File get rowsTs => File(p.join(_self.path, 'rows.ts'));

  File get relationsTs => File(p.join(_self.path, 'relations.ts'));

  File get tablesTs => File(p.join(_self.path, 'tables.ts'));

  File get metadataTs => File(p.join(_self.path, 'metadata.ts'));
}

class FoundationFunctionsDependenciesDatabaseStorage {
  FoundationFunctionsDependenciesDatabaseStorage(Directory parent) : _self = Directory(p.join(parent.path, 'storage'));

  final Directory _self;

  Directory get directory => _self;

  File get adminTs => File(p.join(_self.path, 'admin.ts'));

  File get entityTs => File(p.join(_self.path, 'entity.ts'));

  File get issueTs => File(p.join(_self.path, 'issue.ts'));

  File get resultTs => File(p.join(_self.path, 'result.ts'));

  File get storageTs => File(p.join(_self.path, 'storage.ts'));

  File get userTs => File(p.join(_self.path, 'user.ts'));

  FoundationFunctionsDependenciesStorageClients get clients => FoundationFunctionsDependenciesStorageClients(_self);

  FoundationFunctionsDependenciesDatabaseStorageIdentity get identity => FoundationFunctionsDependenciesDatabaseStorageIdentity(_self);

  FoundationFunctionsDependenciesDatabaseStorageMedia get media => FoundationFunctionsDependenciesDatabaseStorageMedia(_self);
}

class FoundationFunctionsDependenciesStorageClients {
  FoundationFunctionsDependenciesStorageClients(Directory parent) : _self = Directory(p.join(parent.path, 'clients'));

  final Directory _self;

  Directory get directory => _self;

  File get clientTs => File(p.join(_self.path, 'client.ts'));

  File get fileStorageClientTs => File(p.join(_self.path, 'file_storage_client.ts'));

  File get imageStorageClientTs => File(p.join(_self.path, 'image_storage_client.ts'));

  File get resourceTs => File(p.join(_self.path, 'resource.ts'));

  File get videoStorageClientTs => File(p.join(_self.path, 'video_storage_client.ts'));
}

class FoundationFunctionsDependenciesDatabaseStorageIdentity {
  FoundationFunctionsDependenciesDatabaseStorageIdentity(Directory parent) : _self = Directory(p.join(parent.path, 'identity'));

  final Directory _self;

  Directory get directory => _self;

  File get identityGuardTs => File(p.join(_self.path, 'identity_guard.ts'));
}

class FoundationFunctionsDependenciesDatabaseStorageMedia {
  FoundationFunctionsDependenciesDatabaseStorageMedia(Directory parent) : _self = Directory(p.join(parent.path, 'media'));

  final Directory _self;

  Directory get directory => _self;

  File get typesTs => File(p.join(_self.path, 'types.ts'));

  File get validationTs => File(p.join(_self.path, 'validation.ts'));

  File get videoFrameTs => File(p.join(_self.path, 'video_frame.ts'));
}

class FoundationFunctionsDependenciesFeatures {
  FoundationFunctionsDependenciesFeatures(Directory parent) : _self = Directory(p.join(parent.path, 'features'));

  final Directory _self;

  Directory get directory => _self;

  File get featuresTs => File(p.join(_self.path, 'features.ts'));

  FoundationFunctionsDependenciesFeaturesDevops get devops => FoundationFunctionsDependenciesFeaturesDevops(_self);

  FoundationFunctionsDependenciesFeaturesMessagings get messagings => FoundationFunctionsDependenciesFeaturesMessagings(_self);
}

class FoundationFunctionsDependenciesFeaturesDevops {
  FoundationFunctionsDependenciesFeaturesDevops(Directory parent) : _self = Directory(p.join(parent.path, 'devops'));

  final Directory _self;

  Directory get directory => _self;

  File get devopsTs => File(p.join(_self.path, 'devops.ts'));

  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinks get dynamicLinks => FoundationFunctionsDependenciesFeaturesDevopsDynamicLinks(_self);

  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigs get remoteConfigs => FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigs(_self);
}

class FoundationFunctionsDependenciesFeaturesDevopsDynamicLinks {
  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinks(Directory parent) : _self = Directory(p.join(parent.path, 'dynamic-links'));

  final Directory _self;

  Directory get directory => _self;

  File get dynamicLinksTs => File(p.join(_self.path, 'dynamic-links.ts'));

  File get entitiesTs => File(p.join(_self.path, 'entities.ts'));

  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksLink get link => FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksLink(_self);

  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksStatistics get statistics => FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksStatistics(_self);
}

class FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksLink {
  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksLink(Directory parent) : _self = Directory(p.join(parent.path, 'link'));

  final Directory _self;

  Directory get directory => _self;

  File get slugTs => File(p.join(_self.path, '_slug.ts'));

  File get linkDatabaseTs => File(p.join(_self.path, 'link.database.ts'));

  File get linkSupabaseTs => File(p.join(_self.path, 'link.supabase.ts'));

  File get linkTs => File(p.join(_self.path, 'link.ts'));
}

class FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksStatistics {
  FoundationFunctionsDependenciesFeaturesDevopsDynamicLinksStatistics(Directory parent) : _self = Directory(p.join(parent.path, 'statistics'));

  final Directory _self;

  Directory get directory => _self;

  File get statisticsDatabaseTs => File(p.join(_self.path, 'statistics.database.ts'));

  File get statisticsTs => File(p.join(_self.path, 'statistics.ts'));
}

class FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigs {
  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigs(Directory parent) : _self = Directory(p.join(parent.path, 'remote-configs'));

  final Directory _self;

  Directory get directory => _self;

  File get entitiesTs => File(p.join(_self.path, 'entities.ts'));

  File get remoteConfigsTs => File(p.join(_self.path, 'remote-configs.ts'));

  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsConfig get config => FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsConfig(_self);

  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsStatistics get statistics => FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsStatistics(_self);
}

class FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsConfig {
  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsConfig(Directory parent) : _self = Directory(p.join(parent.path, 'config'));

  final Directory _self;

  Directory get directory => _self;

  File get configDatabaseTs => File(p.join(_self.path, 'config.database.ts'));

  File get configTs => File(p.join(_self.path, 'config.ts'));
}

class FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsStatistics {
  FoundationFunctionsDependenciesFeaturesDevopsRemoteConfigsStatistics(Directory parent) : _self = Directory(p.join(parent.path, 'statistics'));

  final Directory _self;

  Directory get directory => _self;

  File get statisticsDatabaseTs => File(p.join(_self.path, 'statistics.database.ts'));

  File get statisticsTs => File(p.join(_self.path, 'statistics.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagings {
  FoundationFunctionsDependenciesFeaturesMessagings(Directory parent) : _self = Directory(p.join(parent.path, 'messagings'));

  final Directory _self;

  Directory get directory => _self;

  File get messagingsTs => File(p.join(_self.path, 'messagings.ts'));

  FoundationFunctionsDependenciesFeaturesMessagingsCampaigns get campaigns => FoundationFunctionsDependenciesFeaturesMessagingsCampaigns(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMail get mail => FoundationFunctionsDependenciesFeaturesMessagingsMail(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPush get notificationPush => FoundationFunctionsDependenciesFeaturesMessagingsNotificationPush(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsSms get sms => FoundationFunctionsDependenciesFeaturesMessagingsSms(_self);
}

class FoundationFunctionsDependenciesFeaturesMessagingsCampaigns {
  FoundationFunctionsDependenciesFeaturesMessagingsCampaigns(Directory parent) : _self = Directory(p.join(parent.path, 'campaigns'));

  final Directory _self;

  Directory get directory => _self;

  File get candidatesTs => File(p.join(_self.path, 'candidates.ts'));

  File get filtersTs => File(p.join(_self.path, 'filters.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMail {
  FoundationFunctionsDependenciesFeaturesMessagingsMail(Directory parent) : _self = Directory(p.join(parent.path, 'mail'));

  final Directory _self;

  Directory get directory => _self;

  File get entitiesTs => File(p.join(_self.path, 'entities.ts'));

  File get mailTs => File(p.join(_self.path, 'mail.ts'));

  FoundationFunctionsDependenciesFeaturesMessagingsMailCampaigns get campaigns => FoundationFunctionsDependenciesFeaturesMessagingsMailCampaigns(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMailComponents get components => FoundationFunctionsDependenciesFeaturesMessagingsMailComponents(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMailL10n get l10n => FoundationFunctionsDependenciesFeaturesMessagingsMailL10n(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMailSend get send => FoundationFunctionsDependenciesFeaturesMessagingsMailSend(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMailStatistics get statistics => FoundationFunctionsDependenciesFeaturesMessagingsMailStatistics(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsMailTemplates get templates => FoundationFunctionsDependenciesFeaturesMessagingsMailTemplates(_self);
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailCampaigns {
  FoundationFunctionsDependenciesFeaturesMessagingsMailCampaigns(Directory parent) : _self = Directory(p.join(parent.path, 'campaigns'));

  final Directory _self;

  Directory get directory => _self;

  File get campaignsDatabaseTs => File(p.join(_self.path, 'campaigns.database.ts'));

  File get campaignsTs => File(p.join(_self.path, 'campaigns.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailComponents {
  FoundationFunctionsDependenciesFeaturesMessagingsMailComponents(Directory parent) : _self = Directory(p.join(parent.path, 'components'));

  final Directory _self;

  Directory get directory => _self;

  File get appTsx => File(p.join(_self.path, 'app.tsx'));

  FoundationFunctionsDependenciesFeaturesMessagingsMailComponentsPrimitives get primitives => FoundationFunctionsDependenciesFeaturesMessagingsMailComponentsPrimitives(_self);
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailComponentsPrimitives {
  FoundationFunctionsDependenciesFeaturesMessagingsMailComponentsPrimitives(Directory parent) : _self = Directory(p.join(parent.path, 'primitives'));

  final Directory _self;

  Directory get directory => _self;

  File get buttonTsx => File(p.join(_self.path, 'button.tsx'));

  File get colorsTs => File(p.join(_self.path, 'colors.ts'));

  File get fontsTs => File(p.join(_self.path, 'fonts.ts'));

  File get linkTextTsx => File(p.join(_self.path, 'link-text.tsx'));

  File get logoTsx => File(p.join(_self.path, 'logo.tsx'));

  File get sectionTsx => File(p.join(_self.path, 'section.tsx'));

  File get separatorTsx => File(p.join(_self.path, 'separator.tsx'));

  File get spacingTsx => File(p.join(_self.path, 'spacing.tsx'));

  File get textTsx => File(p.join(_self.path, 'text.tsx'));

  File get themeTs => File(p.join(_self.path, 'theme.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailL10n {
  FoundationFunctionsDependenciesFeaturesMessagingsMailL10n(Directory parent) : _self = Directory(p.join(parent.path, 'l10n'));

  final Directory _self;

  Directory get directory => _self;

  File get enTs => File(p.join(_self.path, 'en.ts'));

  File get frTs => File(p.join(_self.path, 'fr.ts'));

  File get stringsTs => File(p.join(_self.path, 'strings.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailSend {
  FoundationFunctionsDependenciesFeaturesMessagingsMailSend(Directory parent) : _self = Directory(p.join(parent.path, 'send'));

  final Directory _self;

  Directory get directory => _self;

  File get sendSmtpTs => File(p.join(_self.path, 'send.smtp.ts'));

  File get sendTs => File(p.join(_self.path, 'send.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailStatistics {
  FoundationFunctionsDependenciesFeaturesMessagingsMailStatistics(Directory parent) : _self = Directory(p.join(parent.path, 'statistics'));

  final Directory _self;

  Directory get directory => _self;

  File get statisticsDatabaseTs => File(p.join(_self.path, 'statistics.database.ts'));

  File get statisticsTs => File(p.join(_self.path, 'statistics.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsMailTemplates {
  FoundationFunctionsDependenciesFeaturesMessagingsMailTemplates(Directory parent) : _self = Directory(p.join(parent.path, 'templates'));

  final Directory _self;

  Directory get directory => _self;

  File get templatesDatabaseTs => File(p.join(_self.path, 'templates.database.ts'));

  File get templatesTs => File(p.join(_self.path, 'templates.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsNotificationPush {
  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPush(Directory parent) : _self = Directory(p.join(parent.path, 'notification_push'));

  final Directory _self;

  Directory get directory => _self;

  File get entitiesTs => File(p.join(_self.path, 'entities.ts'));

  File get pushTs => File(p.join(_self.path, 'push.ts'));

  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushOpens get opens => FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushOpens(_self);

  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushSend get send => FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushSend(_self);
}

class FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushOpens {
  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushOpens(Directory parent) : _self = Directory(p.join(parent.path, 'opens'));

  final Directory _self;

  Directory get directory => _self;

  File get opensDatabaseTs => File(p.join(_self.path, 'opens.database.ts'));

  File get opensTs => File(p.join(_self.path, 'opens.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushSend {
  FoundationFunctionsDependenciesFeaturesMessagingsNotificationPushSend(Directory parent) : _self = Directory(p.join(parent.path, 'send'));

  final Directory _self;

  Directory get directory => _self;

  File get fcmSendTs => File(p.join(_self.path, '_fcm_send.ts'));

  File get fcmTokenTs => File(p.join(_self.path, '_fcm_token.ts'));

  File get sendDatabaseTs => File(p.join(_self.path, 'send.database.ts'));

  File get sendTs => File(p.join(_self.path, 'send.ts'));
}

class FoundationFunctionsDependenciesFeaturesMessagingsSms {
  FoundationFunctionsDependenciesFeaturesMessagingsSms(Directory parent) : _self = Directory(p.join(parent.path, 'sms'));

  final Directory _self;

  Directory get directory => _self;

  File get entitiesTs => File(p.join(_self.path, 'entities.ts'));

  File get smsTs => File(p.join(_self.path, 'sms.ts'));

  FoundationFunctionsDependenciesFeaturesMessagingsSmsSend get send => FoundationFunctionsDependenciesFeaturesMessagingsSmsSend(_self);
}

class FoundationFunctionsDependenciesFeaturesMessagingsSmsSend {
  FoundationFunctionsDependenciesFeaturesMessagingsSmsSend(Directory parent) : _self = Directory(p.join(parent.path, 'send'));

  final Directory _self;

  Directory get directory => _self;

  File get sendTs => File(p.join(_self.path, 'send.ts'));

  File get sendTwilioTs => File(p.join(_self.path, 'send.twilio.ts'));
}

class FoundationFunctionsDependenciesGeospatial {
  FoundationFunctionsDependenciesGeospatial(Directory parent) : _self = Directory(p.join(parent.path, 'geospatial'));

  final Directory _self;

  Directory get directory => _self;

  File get geocoderTs => File(p.join(_self.path, 'geocoder.ts'));
}

class FoundationFunctionsDependenciesSecurity {
  FoundationFunctionsDependenciesSecurity(Directory parent) : _self = Directory(p.join(parent.path, 'security'));

  final Directory _self;

  Directory get directory => _self;

  File get securityTs => File(p.join(_self.path, 'security.ts'));

  FoundationFunctionsDependenciesSecurityAuth get auth => FoundationFunctionsDependenciesSecurityAuth(_self);

  FoundationFunctionsDependenciesSecurityVpn get vpn => FoundationFunctionsDependenciesSecurityVpn(_self);
}

class FoundationFunctionsDependenciesSecurityAuth {
  FoundationFunctionsDependenciesSecurityAuth(Directory parent) : _self = Directory(p.join(parent.path, 'auth'));

  final Directory _self;

  Directory get directory => _self;

  File get authTs => File(p.join(_self.path, 'auth.ts'));

  FoundationFunctionsDependenciesSecurityAuthCore get core => FoundationFunctionsDependenciesSecurityAuthCore(_self);

  FoundationFunctionsDependenciesSecurityAuthResetPassword get resetPassword => FoundationFunctionsDependenciesSecurityAuthResetPassword(_self);

  FoundationFunctionsDependenciesSecurityAuthSession get session => FoundationFunctionsDependenciesSecurityAuthSession(_self);

  FoundationFunctionsDependenciesSecurityAuthSignIn get signIn => FoundationFunctionsDependenciesSecurityAuthSignIn(_self);

  FoundationFunctionsDependenciesSecurityAuthSignUp get signUp => FoundationFunctionsDependenciesSecurityAuthSignUp(_self);

  FoundationFunctionsDependenciesSecurityAuthUser get user => FoundationFunctionsDependenciesSecurityAuthUser(_self);
}

class FoundationFunctionsDependenciesSecurityAuthCore {
  FoundationFunctionsDependenciesSecurityAuthCore(Directory parent) : _self = Directory(p.join(parent.path, '_core'));

  final Directory _self;

  Directory get directory => _self;

  File get accountTs => File(p.join(_self.path, 'account.ts'));

  File get cacheTs => File(p.join(_self.path, 'cache.ts'));

  File get cryptoTs => File(p.join(_self.path, 'crypto.ts'));

  File get errorsTs => File(p.join(_self.path, 'errors.ts'));

  File get identityTs => File(p.join(_self.path, 'identity.ts'));

  File get mappersTs => File(p.join(_self.path, 'mappers.ts'));

  File get validatorTs => File(p.join(_self.path, 'validator.ts'));

  FoundationFunctionsDependenciesSecurityAuthCoreGotrue get gotrue => FoundationFunctionsDependenciesSecurityAuthCoreGotrue(_self);
}

class FoundationFunctionsDependenciesSecurityAuthCoreGotrue {
  FoundationFunctionsDependenciesSecurityAuthCoreGotrue(Directory parent) : _self = Directory(p.join(parent.path, 'gotrue'));

  final Directory _self;

  Directory get directory => _self;

  File get gotrueClientTs => File(p.join(_self.path, 'gotrue_client.ts'));

  File get primitivesTs => File(p.join(_self.path, 'primitives.ts'));

  File get resetPasswordTs => File(p.join(_self.path, 'reset_password.ts'));

  File get sessionTs => File(p.join(_self.path, 'session.ts'));

  File get signInTs => File(p.join(_self.path, 'sign_in.ts'));

  File get signUpTs => File(p.join(_self.path, 'sign_up.ts'));

  File get userTs => File(p.join(_self.path, 'user.ts'));

  FoundationFunctionsDependenciesSecurityAuthCoreGotrueSignIn get signIn => FoundationFunctionsDependenciesSecurityAuthCoreGotrueSignIn(_self);
}

class FoundationFunctionsDependenciesSecurityAuthCoreGotrueSignIn {
  FoundationFunctionsDependenciesSecurityAuthCoreGotrueSignIn(Directory parent) : _self = Directory(p.join(parent.path, 'sign_in'));

  final Directory _self;

  Directory get directory => _self;

  File get emailTs => File(p.join(_self.path, 'email.ts'));

  File get phoneTs => File(p.join(_self.path, 'phone.ts'));

  File get socialTs => File(p.join(_self.path, 'social.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthResetPassword {
  FoundationFunctionsDependenciesSecurityAuthResetPassword(Directory parent) : _self = Directory(p.join(parent.path, 'reset_password'));

  final Directory _self;

  Directory get directory => _self;

  File get emailTs => File(p.join(_self.path, '_email.ts'));

  File get phoneTs => File(p.join(_self.path, '_phone.ts'));

  File get resetPasswordTs => File(p.join(_self.path, 'reset_password.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSession {
  FoundationFunctionsDependenciesSecurityAuthSession(Directory parent) : _self = Directory(p.join(parent.path, 'session'));

  final Directory _self;

  Directory get directory => _self;

  File get currentTs => File(p.join(_self.path, '_current.ts'));

  File get deviceTs => File(p.join(_self.path, '_device.ts'));

  File get sessionResultTs => File(p.join(_self.path, '_session_result.ts'));

  File get sessionImplTs => File(p.join(_self.path, 'session.impl.ts'));

  File get sessionTs => File(p.join(_self.path, 'session.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSignIn {
  FoundationFunctionsDependenciesSecurityAuthSignIn(Directory parent) : _self = Directory(p.join(parent.path, 'sign_in'));

  final Directory _self;

  Directory get directory => _self;

  File get signInTs => File(p.join(_self.path, 'sign_in.ts'));

  File get typesTs => File(p.join(_self.path, 'types.ts'));

  FoundationFunctionsDependenciesSecurityAuthSignInOtp get otp => FoundationFunctionsDependenciesSecurityAuthSignInOtp(_self);

  FoundationFunctionsDependenciesSecurityAuthSignInIntra get intra => FoundationFunctionsDependenciesSecurityAuthSignInIntra(_self);

  FoundationFunctionsDependenciesSecurityAuthSignInProviders get providers => FoundationFunctionsDependenciesSecurityAuthSignInProviders(_self);
}

class FoundationFunctionsDependenciesSecurityAuthSignInOtp {
  FoundationFunctionsDependenciesSecurityAuthSignInOtp(Directory parent) : _self = Directory(p.join(parent.path, '_otp'));

  final Directory _self;

  Directory get directory => _self;

  File get otpChallengeTs => File(p.join(_self.path, 'otp_challenge.ts'));

  File get otpChannelTs => File(p.join(_self.path, 'otp_channel.ts'));

  File get pendingTokenTs => File(p.join(_self.path, 'pending_token.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSignInIntra {
  FoundationFunctionsDependenciesSecurityAuthSignInIntra(Directory parent) : _self = Directory(p.join(parent.path, 'intra'));

  final Directory _self;

  Directory get directory => _self;

  File get intraTs => File(p.join(_self.path, 'intra.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSignInProviders {
  FoundationFunctionsDependenciesSecurityAuthSignInProviders(Directory parent) : _self = Directory(p.join(parent.path, 'providers'));

  final Directory _self;

  Directory get directory => _self;

  File get withEmailAndPasswordTs => File(p.join(_self.path, 'with_email_and_password.ts'));

  File get withPhoneTs => File(p.join(_self.path, 'with_phone.ts'));

  File get withSocialTs => File(p.join(_self.path, 'with_social.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSignUp {
  FoundationFunctionsDependenciesSecurityAuthSignUp(Directory parent) : _self = Directory(p.join(parent.path, 'sign_up'));

  final Directory _self;

  Directory get directory => _self;

  File get signUpTs => File(p.join(_self.path, 'sign_up.ts'));

  File get typesTs => File(p.join(_self.path, 'types.ts'));

  FoundationFunctionsDependenciesSecurityAuthSignUpAccount get account => FoundationFunctionsDependenciesSecurityAuthSignUpAccount(_self);

  FoundationFunctionsDependenciesSecurityAuthSignUpProviders get providers => FoundationFunctionsDependenciesSecurityAuthSignUpProviders(_self);
}

class FoundationFunctionsDependenciesSecurityAuthSignUpAccount {
  FoundationFunctionsDependenciesSecurityAuthSignUpAccount(Directory parent) : _self = Directory(p.join(parent.path, 'account'));

  final Directory _self;

  Directory get directory => _self;

  File get adminAccountTs => File(p.join(_self.path, 'admin_account.ts'));

  File get signUpAccountTs => File(p.join(_self.path, 'sign_up_account.ts'));

  File get userAccountTs => File(p.join(_self.path, 'user_account.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthSignUpProviders {
  FoundationFunctionsDependenciesSecurityAuthSignUpProviders(Directory parent) : _self = Directory(p.join(parent.path, 'providers'));

  final Directory _self;

  Directory get directory => _self;

  File get withEmailAndPasswordTs => File(p.join(_self.path, 'with_email_and_password.ts'));

  File get withPhoneTs => File(p.join(_self.path, 'with_phone.ts'));

  File get withSocialTs => File(p.join(_self.path, 'with_social.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthUser {
  FoundationFunctionsDependenciesSecurityAuthUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  File get userImplTs => File(p.join(_self.path, 'user.impl.ts'));

  File get userTs => File(p.join(_self.path, 'user.ts'));

  FoundationFunctionsDependenciesSecurityAuthUserDevices get devices => FoundationFunctionsDependenciesSecurityAuthUserDevices(_self);

  FoundationFunctionsDependenciesSecurityAuthUserUser get user => FoundationFunctionsDependenciesSecurityAuthUserUser(_self);
}

class FoundationFunctionsDependenciesSecurityAuthUserDevices {
  FoundationFunctionsDependenciesSecurityAuthUserDevices(Directory parent) : _self = Directory(p.join(parent.path, 'devices'));

  final Directory _self;

  Directory get directory => _self;

  File get devicesImplTs => File(p.join(_self.path, 'devices.impl.ts'));

  File get devicesTs => File(p.join(_self.path, 'devices.ts'));

  FoundationFunctionsDependenciesSecurityAuthUserDevicesInternal get internal => FoundationFunctionsDependenciesSecurityAuthUserDevicesInternal(_self);
}

class FoundationFunctionsDependenciesSecurityAuthUserDevicesInternal {
  FoundationFunctionsDependenciesSecurityAuthUserDevicesInternal(Directory parent) : _self = Directory(p.join(parent.path, '_internal'));

  final Directory _self;

  Directory get directory => _self;

  File get broadcastTs => File(p.join(_self.path, 'broadcast.ts'));

  File get mapperTs => File(p.join(_self.path, 'mapper.ts'));

  File get ownerResolverTs => File(p.join(_self.path, 'owner_resolver.ts'));

  File get repositoryTs => File(p.join(_self.path, 'repository.ts'));

  File get tokenTs => File(p.join(_self.path, 'token.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthUserUser {
  FoundationFunctionsDependenciesSecurityAuthUserUser(Directory parent) : _self = Directory(p.join(parent.path, 'user'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsDependenciesSecurityAuthUserUserEmail get email => FoundationFunctionsDependenciesSecurityAuthUserUserEmail(_self);

  FoundationFunctionsDependenciesSecurityAuthUserUserPassword get password => FoundationFunctionsDependenciesSecurityAuthUserUserPassword(_self);

  FoundationFunctionsDependenciesSecurityAuthUserUserPhone get phone => FoundationFunctionsDependenciesSecurityAuthUserUserPhone(_self);
}

class FoundationFunctionsDependenciesSecurityAuthUserUserEmail {
  FoundationFunctionsDependenciesSecurityAuthUserUserEmail(Directory parent) : _self = Directory(p.join(parent.path, 'email'));

  final Directory _self;

  Directory get directory => _self;

  File get emailImplTs => File(p.join(_self.path, 'email.impl.ts'));

  File get emailTs => File(p.join(_self.path, 'email.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthUserUserPassword {
  FoundationFunctionsDependenciesSecurityAuthUserUserPassword(Directory parent) : _self = Directory(p.join(parent.path, 'password'));

  final Directory _self;

  Directory get directory => _self;

  File get passwordImplTs => File(p.join(_self.path, 'password.impl.ts'));

  File get passwordTs => File(p.join(_self.path, 'password.ts'));
}

class FoundationFunctionsDependenciesSecurityAuthUserUserPhone {
  FoundationFunctionsDependenciesSecurityAuthUserUserPhone(Directory parent) : _self = Directory(p.join(parent.path, 'phone'));

  final Directory _self;

  Directory get directory => _self;

  File get phoneImplTs => File(p.join(_self.path, 'phone.impl.ts'));

  File get phoneTs => File(p.join(_self.path, 'phone.ts'));
}

class FoundationFunctionsDependenciesSecurityVpn {
  FoundationFunctionsDependenciesSecurityVpn(Directory parent) : _self = Directory(p.join(parent.path, 'vpn'));

  final Directory _self;

  Directory get directory => _self;

  File get sessionTs => File(p.join(_self.path, '_session.ts'));

  File get vpnImplTs => File(p.join(_self.path, 'vpn.impl.ts'));

  File get vpnTs => File(p.join(_self.path, 'vpn.ts'));
}

class HostCoreLint {
  HostCoreLint(Directory parent) : _self = Directory(p.join(parent.path, '.lint'));

  final Directory _self;

  Directory get directory => _self;

  File get privateModuleScopeTs => File(p.join(_self.path, 'private-module-scope.ts'));
}

class HostBoot {
  HostBoot(Directory parent) : _self = Directory(p.join(parent.path, 'boot'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  File get serverTs => File(p.join(_self.path, 'server.ts'));
}

class FoundationFunctionsKernel {
  FoundationFunctionsKernel(Directory parent) : _self = Directory(p.join(parent.path, 'kernel'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsServerIdentity get identity => FoundationFunctionsServerIdentity(_self);

  FoundationFunctionsServerRequest get request => FoundationFunctionsServerRequest(_self);

  FoundationFunctionsServerEndpoint get endpoint => FoundationFunctionsServerEndpoint(_self);

  FoundationFunctionsServerHttp get http => FoundationFunctionsServerHttp(_self);
}

class FoundationFunctionsServerIdentity {
  FoundationFunctionsServerIdentity(Directory parent) : _self = Directory(p.join(parent.path, '_identity'));

  final Directory _self;

  Directory get directory => _self;

  File get adminRbacResolverTs => File(p.join(_self.path, 'admin_rbac_resolver.ts'));

  File get appKeyFirewallTs => File(p.join(_self.path, 'app_key_firewall.ts'));

  File get constantTimeCompareTs => File(p.join(_self.path, 'constant_time_compare.ts'));

  File get identityTs => File(p.join(_self.path, 'identity.ts'));

  File get jwtIdentityResolverTs => File(p.join(_self.path, 'jwt_identity_resolver.ts'));

  File get requestIdentityTs => File(p.join(_self.path, 'request_identity.ts'));

  File get secretFirewallTs => File(p.join(_self.path, 'secret_firewall.ts'));
}

class FoundationFunctionsServerRequest {
  FoundationFunctionsServerRequest(Directory parent) : _self = Directory(p.join(parent.path, '_request'));

  final Directory _self;

  Directory get directory => _self;

  File get requestTs => File(p.join(_self.path, 'request.ts'));

  FoundationFunctionsServerRequestDevice get device => FoundationFunctionsServerRequestDevice(_self);

  FoundationFunctionsServerRequestGeolocation get geolocation => FoundationFunctionsServerRequestGeolocation(_self);

  FoundationFunctionsServerRequestValidation get validation => FoundationFunctionsServerRequestValidation(_self);
}

class FoundationFunctionsServerRequestDevice {
  FoundationFunctionsServerRequestDevice(Directory parent) : _self = Directory(p.join(parent.path, 'device'));

  final Directory _self;

  Directory get directory => _self;

  File get payloadTs => File(p.join(_self.path, 'payload.ts'));

  File get payloadCipherTs => File(p.join(_self.path, 'payload_cipher.ts'));

  File get payloadValidatorTs => File(p.join(_self.path, 'payload_validator.ts'));
}

class FoundationFunctionsServerRequestGeolocation {
  FoundationFunctionsServerRequestGeolocation(Directory parent) : _self = Directory(p.join(parent.path, 'geolocation'));

  final Directory _self;

  Directory get directory => _self;

  File get ipResolverTs => File(p.join(_self.path, 'ip_resolver.ts'));

  File get providerTs => File(p.join(_self.path, 'provider.ts'));

  File get resolverTs => File(p.join(_self.path, 'resolver.ts'));

  FoundationFunctionsServerRequestGeolocationProviders get providers => FoundationFunctionsServerRequestGeolocationProviders(_self);
}

class FoundationFunctionsServerRequestGeolocationProviders {
  FoundationFunctionsServerRequestGeolocationProviders(Directory parent) : _self = Directory(p.join(parent.path, 'providers'));

  final Directory _self;

  Directory get directory => _self;

  File get dbIpProviderTs => File(p.join(_self.path, 'db_ip_provider.ts'));

  File get freeIpApiProviderTs => File(p.join(_self.path, 'free_ip_api_provider.ts'));

  File get ipApiProviderTs => File(p.join(_self.path, 'ip_api_provider.ts'));

  File get ipInfoProviderTs => File(p.join(_self.path, 'ip_info_provider.ts'));

  File get ipWhoProviderTs => File(p.join(_self.path, 'ip_who_provider.ts'));
}

class FoundationFunctionsServerRequestValidation {
  FoundationFunctionsServerRequestValidation(Directory parent) : _self = Directory(p.join(parent.path, 'validation'));

  final Directory _self;

  Directory get directory => _self;

  File get bodySchemaParserTs => File(p.join(_self.path, 'body_schema_parser.ts'));

  File get formSchemaParserTs => File(p.join(_self.path, 'form_schema_parser.ts'));

  File get schemaTs => File(p.join(_self.path, 'schema.ts'));

  FoundationFunctionsServerRequestValidationFieldResolvers get fieldResolvers => FoundationFunctionsServerRequestValidationFieldResolvers(_self);
}

class FoundationFunctionsServerRequestValidationFieldResolvers {
  FoundationFunctionsServerRequestValidationFieldResolvers(Directory parent) : _self = Directory(p.join(parent.path, 'field_resolvers'));

  final Directory _self;

  Directory get directory => _self;

  File get arrayFieldResolverTs => File(p.join(_self.path, 'array_field_resolver.ts'));

  File get fieldResolverTs => File(p.join(_self.path, 'field_resolver.ts'));

  File get fieldResolverFactoryTs => File(p.join(_self.path, 'field_resolver_factory.ts'));

  File get nestedFieldResolverTs => File(p.join(_self.path, 'nested_field_resolver.ts'));

  File get scalarFieldResolverTs => File(p.join(_self.path, 'scalar_field_resolver.ts'));
}

class FoundationFunctionsServerEndpoint {
  FoundationFunctionsServerEndpoint(Directory parent) : _self = Directory(p.join(parent.path, 'endpoint'));

  final Directory _self;

  Directory get directory => _self;

  File get apiTs => File(p.join(_self.path, 'api.ts'));

  File get serviceTs => File(p.join(_self.path, 'service.ts'));

  File get webhookTs => File(p.join(_self.path, 'webhook.ts'));
}

class FoundationFunctionsServerHttp {
  FoundationFunctionsServerHttp(Directory parent) : _self = Directory(p.join(parent.path, 'http'));

  final Directory _self;

  Directory get directory => _self;

  File get edgeRuntimeShimTs => File(p.join(_self.path, 'edge_runtime_shim.ts'));

  File get htmlPageTs => File(p.join(_self.path, 'html_page.ts'));

  FoundationFunctionsServerHttpInternal get internal => FoundationFunctionsServerHttpInternal(_self);
}

class FoundationFunctionsServerHttpInternal {
  FoundationFunctionsServerHttpInternal(Directory parent) : _self = Directory(p.join(parent.path, '_internal'));

  final Directory _self;

  Directory get directory => _self;

  File get contextTs => File(p.join(_self.path, 'context.ts'));

  File get loggerTs => File(p.join(_self.path, 'logger.ts'));

  File get middlewareTs => File(p.join(_self.path, 'middleware.ts'));

  File get responsesTs => File(p.join(_self.path, 'responses.ts'));

  File get routerTs => File(p.join(_self.path, 'router.ts'));

  File get serveTs => File(p.join(_self.path, 'serve.ts'));
}

class FoundationFunctionsRuntime {
  FoundationFunctionsRuntime(Directory parent) : _self = Directory(p.join(parent.path, 'runtime'));

  final Directory _self;

  Directory get directory => _self;

  File get kvTs => File(p.join(_self.path, '_kv.ts'));

  FoundationFunctionsDependenciesSystemCron get cron => FoundationFunctionsDependenciesSystemCron(_self);

  FoundationFunctionsDependenciesSystemHook get hook => FoundationFunctionsDependenciesSystemHook(_self);

  FoundationFunctionsDependenciesSystemQueue get queue => FoundationFunctionsDependenciesSystemQueue(_self);

  FoundationFunctionsDependenciesSystemValkery get valkery => FoundationFunctionsDependenciesSystemValkery(_self);

  FoundationFunctionsDependenciesSystemRateLimiter get rateLimiter => FoundationFunctionsDependenciesSystemRateLimiter(_self);
}

class FoundationFunctionsDependenciesSystemRateLimiter {
  FoundationFunctionsDependenciesSystemRateLimiter(Directory parent) : _self = Directory(p.join(parent.path, 'rate_limiter'));

  final Directory _self;

  Directory get directory => _self;

  File get rateLimiterImplTs => File(p.join(_self.path, 'rate_limiter.impl.ts'));

  File get rateLimiterTs => File(p.join(_self.path, 'rate_limiter.ts'));
}

class FoundationFunctionsDependenciesSystemCron {
  FoundationFunctionsDependenciesSystemCron(Directory parent) : _self = Directory(p.join(parent.path, 'cron'));

  final Directory _self;

  Directory get directory => _self;

  File get nextRunTs => File(p.join(_self.path, '_next_run.ts'));

  File get entityTs => File(p.join(_self.path, 'entity.ts'));

  File get projectTs => File(p.join(_self.path, 'project.ts'));

  File get registryTs => File(p.join(_self.path, 'registry.ts'));

  File get scheduleTs => File(p.join(_self.path, 'schedule.ts'));

  File get timeTs => File(p.join(_self.path, 'time.ts'));

  File get timezoneTs => File(p.join(_self.path, 'timezone.ts'));
}

class FoundationFunctionsDependenciesSystemHook {
  FoundationFunctionsDependenciesSystemHook(Directory parent) : _self = Directory(p.join(parent.path, 'hook'));

  final Directory _self;

  Directory get directory => _self;

  File get accountTs => File(p.join(_self.path, 'account.ts'));

  File get authTs => File(p.join(_self.path, 'auth.ts'));

  File get hookTs => File(p.join(_self.path, 'hook.ts'));

  File get hooksTs => File(p.join(_self.path, 'hooks.ts'));
}

class FoundationFunctionsDependenciesSystemQueue {
  FoundationFunctionsDependenciesSystemQueue(Directory parent) : _self = Directory(p.join(parent.path, 'queue'));

  final Directory _self;

  Directory get directory => _self;

  File get engineTs => File(p.join(_self.path, 'engine.ts'));

  File get entityTs => File(p.join(_self.path, 'entity.ts'));

  File get internalTs => File(p.join(_self.path, 'internal.ts'));

  File get natsTs => File(p.join(_self.path, 'nats.ts'));

  File get queueTs => File(p.join(_self.path, 'queue.ts'));

  File get registryTs => File(p.join(_self.path, 'registry.ts'));

  FoundationFunctionsDependenciesSystemQueueInternal get internal => FoundationFunctionsDependenciesSystemQueueInternal(_self);
}

class FoundationFunctionsDependenciesSystemQueueInternal {
  FoundationFunctionsDependenciesSystemQueueInternal(Directory parent) : _self = Directory(p.join(parent.path, '_internal'));

  final Directory _self;

  Directory get directory => _self;

  File get internalTs => File(p.join(_self.path, 'internal.ts'));

  File get logsTs => File(p.join(_self.path, 'logs.ts'));

  File get queueTypeTs => File(p.join(_self.path, 'queue_type.ts'));

  File get searcherSyncTs => File(p.join(_self.path, 'searcher-sync.ts'));
}

class FoundationFunctionsDependenciesSystemValkery {
  FoundationFunctionsDependenciesSystemValkery(Directory parent) : _self = Directory(p.join(parent.path, 'valkery'));

  final Directory _self;

  Directory get directory => _self;

  File get valkeryTs => File(p.join(_self.path, 'valkery.ts'));
}

class FoundationFunctionsTests {
  FoundationFunctionsTests(Directory parent) : _self = Directory(p.join(parent.path, 'tests'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsTestsMocks get mocks => FoundationFunctionsTestsMocks(_self);

  FoundationFunctionsTestsTests get tests => FoundationFunctionsTestsTests(_self);
}

class FoundationFunctionsTestsMocks {
  FoundationFunctionsTestsMocks(Directory parent) : _self = Directory(p.join(parent.path, 'mocks'));

  final Directory _self;

  Directory get directory => _self;

  File get autoMockTs => File(p.join(_self.path, 'auto_mock.ts'));

  File get dynamicLinksTs => File(p.join(_self.path, 'dynamic_links.ts'));

  File get geocoderTs => File(p.join(_self.path, 'geocoder.ts'));

  File get installTs => File(p.join(_self.path, 'install.ts'));

  File get installKvTs => File(p.join(_self.path, 'install_kv.ts'));

  File get searcherTs => File(p.join(_self.path, 'searcher.ts'));

  FoundationFunctionsTestsMocksDatabase get database => FoundationFunctionsTestsMocksDatabase(_self);

  FoundationFunctionsTestsMocksMessaging get messaging => FoundationFunctionsTestsMocksMessaging(_self);

  FoundationFunctionsTestsMocksSecurity get security => FoundationFunctionsTestsMocksSecurity(_self);
}

class FoundationFunctionsTestsMocksDatabase {
  FoundationFunctionsTestsMocksDatabase(Directory parent) : _self = Directory(p.join(parent.path, 'database'));

  final Directory _self;

  Directory get directory => _self;

  File get authTs => File(p.join(_self.path, 'auth.ts'));

  File get broadcastTs => File(p.join(_self.path, 'broadcast.ts'));

  File get fakePostgrestTs => File(p.join(_self.path, 'fake_postgrest.ts'));

  File get installRestTs => File(p.join(_self.path, 'install_rest.ts'));

  File get restTs => File(p.join(_self.path, 'rest.ts'));

  File get storageTs => File(p.join(_self.path, 'storage.ts'));
}

class FoundationFunctionsTestsMocksMessaging {
  FoundationFunctionsTestsMocksMessaging(Directory parent) : _self = Directory(p.join(parent.path, 'messaging'));

  final Directory _self;

  Directory get directory => _self;

  File get mailTs => File(p.join(_self.path, 'mail.ts'));

  File get pushTs => File(p.join(_self.path, 'push.ts'));
}

class FoundationFunctionsTestsMocksSecurity {
  FoundationFunctionsTestsMocksSecurity(Directory parent) : _self = Directory(p.join(parent.path, 'security'));

  final Directory _self;

  Directory get directory => _self;

  File get vpnTs => File(p.join(_self.path, 'vpn.ts'));
}

class FoundationFunctionsTestsTests {
  FoundationFunctionsTestsTests(Directory parent) : _self = Directory(p.join(parent.path, 'tests'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsTestsTestsClient get client => FoundationFunctionsTestsTestsClient(_self);

  FoundationFunctionsTestsTestsMocks get mocks => FoundationFunctionsTestsTestsMocks(_self);

  FoundationFunctionsTestsTestsShared get shared => FoundationFunctionsTestsTestsShared(_self);
}

class FoundationFunctionsTestsTestsMocks {
  FoundationFunctionsTestsTestsMocks(Directory parent) : _self = Directory(p.join(parent.path, 'mocks'));

  final Directory _self;

  Directory get directory => _self;

  File get autoMockTestTs => File(p.join(_self.path, 'auto_mock.test.ts'));

  File get dynamicLinksTestTs => File(p.join(_self.path, 'dynamic_links.test.ts'));

  File get geocoderTestTs => File(p.join(_self.path, 'geocoder.test.ts'));

  File get installTestTs => File(p.join(_self.path, 'install.test.ts'));

  File get installKvTestTs => File(p.join(_self.path, 'install_kv.test.ts'));

  File get searcherTestTs => File(p.join(_self.path, 'searcher.test.ts'));

  FoundationFunctionsTestsTestsMocksDatabase get database => FoundationFunctionsTestsTestsMocksDatabase(_self);

  FoundationFunctionsTestsTestsMocksMessaging get messaging => FoundationFunctionsTestsTestsMocksMessaging(_self);

  FoundationFunctionsTestsTestsMocksSecurity get security => FoundationFunctionsTestsTestsMocksSecurity(_self);
}

class FoundationFunctionsTestsTestsMocksDatabase {
  FoundationFunctionsTestsTestsMocksDatabase(Directory parent) : _self = Directory(p.join(parent.path, 'database'));

  final Directory _self;

  Directory get directory => _self;

  File get authTestTs => File(p.join(_self.path, 'auth.test.ts'));

  File get broadcastTestTs => File(p.join(_self.path, 'broadcast.test.ts'));

  File get fakePostgrestTestTs => File(p.join(_self.path, 'fake_postgrest.test.ts'));

  File get installRestTestTs => File(p.join(_self.path, 'install_rest.test.ts'));

  File get restTestTs => File(p.join(_self.path, 'rest.test.ts'));

  File get storageTestTs => File(p.join(_self.path, 'storage.test.ts'));
}

class FoundationFunctionsTestsTestsMocksMessaging {
  FoundationFunctionsTestsTestsMocksMessaging(Directory parent) : _self = Directory(p.join(parent.path, 'messaging'));

  final Directory _self;

  Directory get directory => _self;

  File get mailTestTs => File(p.join(_self.path, 'mail.test.ts'));

  File get pushTestTs => File(p.join(_self.path, 'push.test.ts'));
}

class FoundationFunctionsTestsTestsMocksSecurity {
  FoundationFunctionsTestsTestsMocksSecurity(Directory parent) : _self = Directory(p.join(parent.path, 'security'));

  final Directory _self;

  Directory get directory => _self;

  File get vpnTestTs => File(p.join(_self.path, 'vpn.test.ts'));
}

class FoundationFunctionsTestsTestsClient {
  FoundationFunctionsTestsTestsClient(Directory parent) : _self = Directory(p.join(parent.path, 'runtime'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsTestsTestsClientSrc get src => FoundationFunctionsTestsTestsClientSrc(_self);
}

class FoundationFunctionsTestsTestsClientSrc {
  FoundationFunctionsTestsTestsClientSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsTestsTestsClientSrcSystem get system => FoundationFunctionsTestsTestsClientSrcSystem(_self);
}

class FoundationFunctionsTestsTestsClientSrcSystem {
  FoundationFunctionsTestsTestsClientSrcSystem(Directory parent) : _self = Directory(p.join(parent.path, 'system'));

  final Directory _self;

  Directory get directory => _self;

  FoundationFunctionsTestsTestsClientSrcSystemCron get cron => FoundationFunctionsTestsTestsClientSrcSystemCron(_self);

  FoundationFunctionsTestsTestsClientSrcSystemHook get hook => FoundationFunctionsTestsTestsClientSrcSystemHook(_self);

  FoundationFunctionsTestsTestsClientSrcSystemQueue get queue => FoundationFunctionsTestsTestsClientSrcSystemQueue(_self);
}

class FoundationFunctionsTestsTestsClientSrcSystemCron {
  FoundationFunctionsTestsTestsClientSrcSystemCron(Directory parent) : _self = Directory(p.join(parent.path, 'cron'));

  final Directory _self;

  Directory get directory => _self;

  File get nextRunTestTs => File(p.join(_self.path, 'next_run.test.ts'));

  File get registryTestTs => File(p.join(_self.path, 'registry.test.ts'));

  File get scheduleTestTs => File(p.join(_self.path, 'schedule.test.ts'));
}

class FoundationFunctionsTestsTestsClientSrcSystemHook {
  FoundationFunctionsTestsTestsClientSrcSystemHook(Directory parent) : _self = Directory(p.join(parent.path, 'hook'));

  final Directory _self;

  Directory get directory => _self;

  File get hookTestTs => File(p.join(_self.path, 'hook.test.ts'));
}

class FoundationFunctionsTestsTestsClientSrcSystemQueue {
  FoundationFunctionsTestsTestsClientSrcSystemQueue(Directory parent) : _self = Directory(p.join(parent.path, 'queue'));

  final Directory _self;

  Directory get directory => _self;

  File get entityTestTs => File(p.join(_self.path, 'entity.test.ts'));

  File get registryTestTs => File(p.join(_self.path, 'registry.test.ts'));
}

class FoundationFunctionsTestsTestsShared {
  FoundationFunctionsTestsTestsShared(Directory parent) : _self = Directory(p.join(parent.path, 'shared'));

  final Directory _self;

  Directory get directory => _self;
}

class FoundationHosting {
  FoundationHosting(Directory parent) : _self = Directory(p.join(parent.path, 'web'));

  final Directory _self;

  Directory get directory => _self;

  File get packageLockJson => File(p.join(_self.path, 'package-lock.json'));

  File get packageJson => File(p.join(_self.path, 'package.json'));

  FoundationHostingDevelopersDocs get developersDocs => FoundationHostingDevelopersDocs(_self);

  FoundationHostingPackages get packages => FoundationHostingPackages(_self);

  FoundationHostingNodeModules get nodeModules => FoundationHostingNodeModules(_self);
}

class FoundationHostingDevelopersDocs {
  FoundationHostingDevelopersDocs(Directory parent) : _self = Directory(p.join(parent.path, 'developers_docs'));

  final Directory _self;

  Directory get directory => _self;

  File get indexHtml => File(p.join(_self.path, 'index.html'));

  File get packageLockJson => File(p.join(_self.path, 'package-lock.json'));

  File get packageJson => File(p.join(_self.path, 'package.json'));

  File get tsconfigJson => File(p.join(_self.path, 'tsconfig.json'));

  File get tsconfigTsbuildinfo => File(p.join(_self.path, 'tsconfig.tsbuildinfo'));

  File get viteConfigTs => File(p.join(_self.path, 'vite.config.ts'));

  FoundationHostingDevelopersDocsPublic get public => FoundationHostingDevelopersDocsPublic(_self);

  FoundationHostingDevelopersDocsSrc get src => FoundationHostingDevelopersDocsSrc(_self);

  FoundationHostingDevelopersDocsNodeModules get nodeModules => FoundationHostingDevelopersDocsNodeModules(_self);

}

class FoundationHostingDevelopersDocsPublic {
  FoundationHostingDevelopersDocsPublic(Directory parent) : _self = Directory(p.join(parent.path, 'public'));

  final Directory _self;

  Directory get directory => _self;

  File get logoDarkPng => File(p.join(_self.path, 'logo-dark.png'));

  File get logoLightPng => File(p.join(_self.path, 'logo-light.png'));
}

class FoundationHostingDevelopersDocsSrc {
  FoundationHostingDevelopersDocsSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get appTsx => File(p.join(_self.path, 'App.tsx'));

  File get mainTsx => File(p.join(_self.path, 'main.tsx'));

  File get viteEnvDTs => File(p.join(_self.path, 'vite-env.d.ts'));

  FoundationHostingDevelopersDocsSrcComponents get components => FoundationHostingDevelopersDocsSrcComponents(_self);

  FoundationHostingDevelopersDocsSrcLanding get landing => FoundationHostingDevelopersDocsSrcLanding(_self);

  FoundationHostingDevelopersDocsSrcStyles get styles => FoundationHostingDevelopersDocsSrcStyles(_self);
}

class FoundationHostingDevelopersDocsSrcComponents {
  FoundationHostingDevelopersDocsSrcComponents(Directory parent) : _self = Directory(p.join(parent.path, 'components'));

  final Directory _self;

  Directory get directory => _self;

  File get logoTsx => File(p.join(_self.path, 'Logo.tsx'));
}

class FoundationHostingDevelopersDocsSrcLanding {
  FoundationHostingDevelopersDocsSrcLanding(Directory parent) : _self = Directory(p.join(parent.path, 'landing'));

  final Directory _self;

  Directory get directory => _self;

  File get landingTsx => File(p.join(_self.path, 'Landing.tsx'));

  File get landingCss => File(p.join(_self.path, 'landing.css'));

  File get mainTsx => File(p.join(_self.path, 'main.tsx'));
}

class FoundationHostingDevelopersDocsSrcStyles {
  FoundationHostingDevelopersDocsSrcStyles(Directory parent) : _self = Directory(p.join(parent.path, 'styles'));

  final Directory _self;

  Directory get directory => _self;

  File get globalCss => File(p.join(_self.path, 'global.css'));
}

class FoundationHostingDevelopersDocsNodeModules {
  FoundationHostingDevelopersDocsNodeModules(Directory parent) : _self = Directory(p.join(parent.path, 'node_modules'));

  final Directory _self;

  Directory get directory => _self;
}

class FoundationHostingPackages {
  FoundationHostingPackages(Directory parent) : _self = Directory(p.join(parent.path, 'packages'));

  final Directory _self;

  Directory get directory => _self;

  FoundationHostingPackagesUi get ui => FoundationHostingPackagesUi(_self);
}

class FoundationHostingPackagesUi {
  FoundationHostingPackagesUi(Directory parent) : _self = Directory(p.join(parent.path, 'ui'));

  final Directory _self;

  Directory get directory => _self;

  File get packageJson => File(p.join(_self.path, 'package.json'));

  File get tsconfigJson => File(p.join(_self.path, 'tsconfig.json'));

  FoundationHostingPackagesUiSrc get src => FoundationHostingPackagesUiSrc(_self);
}

class FoundationHostingPackagesUiSrc {
  FoundationHostingPackagesUiSrc(Directory parent) : _self = Directory(p.join(parent.path, 'src'));

  final Directory _self;

  Directory get directory => _self;

  File get indexTs => File(p.join(_self.path, 'index.ts'));

  FoundationHostingPackagesUiSrcHooks get hooks => FoundationHostingPackagesUiSrcHooks(_self);

  FoundationHostingPackagesUiSrcPrimitives get primitives => FoundationHostingPackagesUiSrcPrimitives(_self);
}

class FoundationHostingPackagesUiSrcHooks {
  FoundationHostingPackagesUiSrcHooks(Directory parent) : _self = Directory(p.join(parent.path, 'hooks'));

  final Directory _self;

  Directory get directory => _self;

  File get usedarkmodeTs => File(p.join(_self.path, 'useDarkMode.ts'));
}

class FoundationHostingPackagesUiSrcPrimitives {
  FoundationHostingPackagesUiSrcPrimitives(Directory parent) : _self = Directory(p.join(parent.path, 'primitives'));

  final Directory _self;

  Directory get directory => _self;

  File get buttonTsx => File(p.join(_self.path, 'button.tsx'));

  File get colorsTs => File(p.join(_self.path, 'colors.ts'));

  File get fontsTs => File(p.join(_self.path, 'fonts.ts'));

  File get linkTextTsx => File(p.join(_self.path, 'link-text.tsx'));

  File get sectionTsx => File(p.join(_self.path, 'section.tsx'));

  File get separatorTsx => File(p.join(_self.path, 'separator.tsx'));

  File get spacingTsx => File(p.join(_self.path, 'spacing.tsx'));

  File get textTsx => File(p.join(_self.path, 'text.tsx'));

  File get tokensCss => File(p.join(_self.path, 'tokens.css'));
}

class FoundationHostingNodeModules {
  FoundationHostingNodeModules(Directory parent) : _self = Directory(p.join(parent.path, 'node_modules'));

  final Directory _self;

  Directory get directory => _self;
}

class FoundationProxy {
  FoundationProxy(Directory parent) : _self = Directory(p.join(parent.path, 'proxy'));

  final Directory _self;

  Directory get directory => _self;

  FoundationProxyCaddy get caddy => FoundationProxyCaddy(_self);
}

class FoundationProxyCaddy {
  FoundationProxyCaddy(Directory parent) : _self = Directory(p.join(parent.path, 'caddy'));

  final Directory _self;

  Directory get directory => _self;

  File get caddyfile => File(p.join(_self.path, 'Caddyfile'));
}

class FoundationOpensearch {
  FoundationOpensearch(Directory parent) : _self = Directory(p.join(parent.path, 'opensearch'));

  final Directory _self;

  Directory get directory => _self;
}

class FoundationStorage {
  FoundationStorage(Directory parent) : _self = Directory(p.join(parent.path, 'storage'));

  final Directory _self;

  Directory get directory => _self;
}

