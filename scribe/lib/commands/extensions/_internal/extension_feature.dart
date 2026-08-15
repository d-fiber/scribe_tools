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

import '../../../core/logger.dart';

/// Un feature scaffoldable/supprimable sous `lib/extensions/<name>/`,
/// dispatché depuis ExtensionsCommand (`koko extensions --set|--unset <name>`).
abstract class ExtensionFeature {
  const ExtensionFeature();

  String get name;

  /// Scaffold la feature si elle n'existe pas déjà (no-op sinon, jamais
  /// destructif).
  Future<void> set(Log log);

  /// Supprime la feature. [yes] est ignoré par les features qui ne demandent
  /// jamais de confirmation (hooks) ; requis pour celles qui sont
  /// destructives sur du code métier potentiellement écrit à la main
  /// (queue, cron) — si false, affiche ce qui serait supprimé sans agir.
  Future<void> unset(Log log, {required bool yes});
}
