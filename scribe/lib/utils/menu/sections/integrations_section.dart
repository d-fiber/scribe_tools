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

import '../../../core/console/console.dart';

const List<String> objectStorageIntegrations = <String>['s3', 'backup'];
const List<String> _objectStorageFields = <String>['bucket', 'endpoint', 'region', 'access_key', 'secret_key'];

List<MenuValue> integrationFields(String integration, List<String> names, {SuffixBuilder suffix = optionalValue}) =>
    <MenuValue>[
      for (final String field in names) MenuValue(field, <String>['integrations', integration, field], suffix: suffix),
    ];

List<MenuValue> objectStorageFields(String integration, {SuffixBuilder suffix = optionalValue}) =>
    integrationFields(integration, _objectStorageFields, suffix: suffix);

MenuEntry integrationsEntry({SuffixBuilder suffix = optionalValue}) => MenuGroup(
  'integrations',
  (MenuDocument document) => <MenuEntry>[
    _allOrNothing('fcm', const <String>['project_id', 'client_email', 'private_key'], document, suffix),
    MenuValue('geocoding_api_key', const <String>['integrations', 'geocoding_api_key'], suffix: suffix),
    _allOrNothing('twilio', const <String>['account_sid', 'auth_token', 'message_service_sid'], document, suffix),
    _allOrNothing('google', const <String>['client_id', 'client_secret', 'additional_client_ids'], document, suffix),
    _allOrNothing('apple', const <String>['client_id', 'client_secret', 'additional_client_ids'], document, suffix),
    for (final String integration in objectStorageIntegrations)
      _allOrNothing(integration, _objectStorageFields, document, suffix),
  ],
);

String? integrationsError(MenuDocument document) {
  for (final String integration in objectStorageIntegrations) {
    final List<MenuValue> group = objectStorageFields(integration);
    if (!group.any((MenuValue field) => document.filled(field.path))) continue;
    for (final MenuValue field in group) {
      if (!document.filled(field.path)) return 'Fill in ${field.label} for $integration before saving.';
    }
  }
  return null;
}

MenuEntry _allOrNothing(String integration, List<String> names, MenuDocument document, SuffixBuilder suffix) {
  final List<MenuValue> fields = integrationFields(integration, names, suffix: suffix);

  return MenuGroup(
    integration,
    (MenuDocument _) => <MenuEntry>[
      for (final MenuValue field in fields)
        field.copyWith(
          validate: (String value) {
            if (value.length > 1000) return '${field.label} is too long';
            final bool othersFilled = fields.any(
              (MenuValue other) => other.path != field.path && document.filled(other.path),
            );
            if (value.trim().isEmpty && othersFilled) {
              return '${field.label} is required because other fields in $integration are already set';
            }
            return null;
          },
        ),
    ],
  );
}
