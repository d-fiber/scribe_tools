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

import 'package:scribe/core/file_system_entity/tree/alchemy/alchemy.dart';
import 'package:scribe/core/file_system_entity/tree/kernel/kernel.dart';
import 'package:scribe/core/file_system_entity/tree/project/project.dart';
import 'package:path/path.dart' as p;

class Paths {
  static Directory get root {
    final File scriptFile = File(Platform.script.toFilePath());
    return Directory(scriptFile.parent.parent.parent.parent.path);
  }

  static Project get project => Project(p.join(root.path, 'lib'));
  static Directory get assets => Directory(p.join(root.path, 'assets'));
  static Alchemy get alchemy => Alchemy(p.join(root.path, generatedDirectory));
  static Kernel get kernel => Kernel(root.path);

  /// Le nom du projet, lu sur le dossier qui le contient.
  ///
  /// C'est lui qui nomme la sortie de generation et son alias d'import, pour
  /// qu'un depot ne porte jamais le nom d'un autre. Voir
  /// `.claude/scribe/global.md` § « La sortie de generation ».
  static String get projectName => p.basename(root.path);

  static String get generatedDirectory => '.$projectName';

  static String get generatedAlias => '@$projectName/';

  /// La racine du SDK, telle que le compose et les gabarits la referencent.
  ///
  /// Relative a la racine du projet tant que `scribe/` vit dans le depot ; ce
  /// getter est le seul endroit a changer le jour ou le SDK est installe
  /// ailleurs. Voir `.claude/scribe/global.md` § « Sortir le SDK ».
  static String get sdkRoot => './scribe';
}
