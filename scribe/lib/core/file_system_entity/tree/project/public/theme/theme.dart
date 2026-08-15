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

import 'package:scribe/core/file_system_entity/node.dart';
import 'package:scribe/core/file_system_entity/source.dart';
import 'package:path/path.dart' as p;

// Tokens couleurs/typo Poppin (lib/public/theme/), mirroités vers scribe/web/packages/ui
// par `koko gen code` (scribe/host/public/public/mail/ n'a plus besoin de mirror, `DesignSystem`
// les reçoit par injection, voir .claude/lib/public/theme.md). Pas de design-system.tsx ici
// (2026-07-30, supprimé, dossier renommé design-system/ → theme/ le même jour) : le fichier qui
// instancie `DesignSystem` vit sous scribe/host/public/public/ (mail/design-system.tsx,
// theme/tokens.ts), voir .claude/scribe/host/public/public/theme.md.
class Theme extends Node {
  final String parent;
  final String current;

  Theme({required this.parent, required this.current}) : super(p.join(parent, current));

  Source get colors => Source(p.join(path, "colors.ts"));
  Source get fonts => Source(p.join(path, "fonts.ts"));
}
