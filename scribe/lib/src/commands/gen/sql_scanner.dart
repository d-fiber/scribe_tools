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


import 'package:file/file.dart';

import 'package:path/path.dart' as p;

import 'package:scribe/src/dependencies.dart';
import 'package:scribe/src/globals.dart' as globals;

List<Directory> kernelSqlRoots() => <Directory>[
  globals.project.sdk.hostDbInit,
  ..._moduleSqlRoots(),
  globals.project.sdk.hostDbMigrations,
];

List<Directory> _moduleSqlRoots() {
  final List<Directory> roots = <Directory>[
    for (final Dependency dependency in Dependencies.load().active)
      if (dependency.sql case final String sql) globals.fs.directory(p.join(dependency.directory.path, sql)),
  ];
  roots.sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return roots;
}

Future<void> walkSqlFiles(Directory dir, Future<void> Function(File file) visit) async {
  if (!dir.existsSync()) return;
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    if (entity is Directory) {
      await walkSqlFiles(entity, visit);
    } else if (entity is File && entity.path.endsWith('.sql')) {
      await visit(entity);
    }
  }
}
