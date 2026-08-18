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

import 'package:path/path.dart' as p;
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/dependencies.dart';
import 'package:scribe/src/globals.dart' as globals;

/// Writes the imports that wire every mounted module into the host's ports.
///
/// A module carries a [registrationFile] only when it has something to hand
/// over, so the list is usually shorter than the mounted one. A module without
/// it contributes containers, SQL or a client and nothing the host has to be
/// told about.
///
/// The specifier is built from where the module actually sits, which is why it
/// survives the move to `host/packages/`: the two roots render the same way
/// under the `@scribe/host/` alias.
Future<void> generateRegistrations() async {
  final Dependencies dependencies = Dependencies.load();
  final String host = globals.project.sdk.host.path;

  final List<String> specifiers = <String>[
    for (final Dependency dependency in dependencies.active)
      if (dependency.directory.childFile(registrationFile).existsSync())
        '@scribe/host/${p.url.joinAll(p.split(p.relative(dependency.directory.path, from: host)))}/$registrationFile',
  ]..sort();

  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.registrations.writeAsString(
    '// This file is auto-generated do not edit manually.\n'
    '// Run: $kToolName gen code\n'
    '\n'
    '${specifiers.map((String specifier) => 'import "$specifier";').join('\n')}'
    '${specifiers.isEmpty ? '' : '\n'}',
  );

  globals.logger.printStatus(
    '${specifiers.length} module registration(s) → ${globals.project.generatedDirectoryName}/sdk/js/registrations.ts',
  );
}
