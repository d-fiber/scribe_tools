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

import '../../../core/paths/infra_files.dart';

class Site {
  Site({required this.name, required this.directory, required this.distDirectories, required this.buildScripts});

  final String name;
  final Directory directory;
  final List<Directory> distDirectories;
  final List<String> buildScripts;
}

List<Site> hostedSites() => <Site>[
  Site(
    name: 'developers_docs',
    directory: InfraFiles.tree.scribe.hosting.developersDocs.directory,
    distDirectories: _builtVariants(),
    buildScripts: const <String>['build'],
  ),
];

/// Les variantes construites vivent dans la sortie generee, pas dans le SDK :
/// `scribe/` ne porte aucune trace du projet qui le consomme.
List<Directory> _builtVariants() {
  final Directory dist = InfraFiles.tree.alchemy.docs.dist.directory;
  if (!dist.existsSync()) return const <Directory>[];

  return dist.listSync(followLinks: false).whereType<Directory>().toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
}
