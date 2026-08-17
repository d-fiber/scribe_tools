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
import 'package:scribe/src/commands/doctor/report.dart';
import 'package:scribe/src/project.dart';
import 'package:scribe/src/scribe_manifest.dart';
import 'package:scribe/src/secrets.dart';

/// The project here, and what is missing from it.
///
/// Being outside a project is not a failure. This command prepares a machine as
/// much as it checks a project, and a machine is prepared before there is one.
///
/// This is also the only place the manifest's problems are shown without the
/// command refusing to run: everywhere else they throw.
DoctorSection projectSection() {
  final Project? here = Project.currentOrNull;

  if (here == null) {
    return const DoctorSection(
      title: 'Project',
      summary: 'none here',
      findings: <Finding>[
        Finding.note(
          'no ${Project.configFileName} in this directory',
          hint: 'Run `scribe create <name>` to start one, or cd to the root of a project.',
        ),
      ],
    );
  }

  return DoctorSection(
    title: 'Project',
    summary: here.name,
    findings: <Finding>[..._entries(here), ..._manifest(here), ..._secrets(here)],
  );
}

/// The three things a project is made of, and the two of them a machine can restore.
///
/// A directory can be created from nothing. A `config.yaml` and an entrypoint
/// cannot: what they hold is the project itself, and writing an empty one would
/// turn a clear failure into a project that starts and does nothing.
List<Finding> _entries(Project project) {
  final List<Finding> findings = <Finding>[];

  if (project.config.existsSync()) {
    findings.add(Finding.ok('${Project.configFileName} is here'));
  } else {
    findings.add(
      Finding.problem(
        '${Project.configFileName} is missing',
        hint: 'Run `scribe create <name>` from the directory above to write a project that has one.',
      ),
    );
  }

  for (final MapEntry<String, Directory> entry in <String, Directory>{
    'lib/': project.lib,
    'lib/src/': project.sources,
  }.entries) {
    if (entry.value.existsSync()) {
      findings.add(Finding.ok('${entry.key} is here'));
      continue;
    }

    findings.add(
      Finding.problem(
        '${entry.key} is missing',
        hint: 'Run `scribe doctor --rescue` to create it.',
        repair: () => entry.value.create(recursive: true),
      ),
    );
  }

  if (project.entrypoint.existsSync()) {
    findings.add(Finding.ok('lib/${project.entrypoint.basename} is here'));
  } else {
    findings.add(
      Finding.problem(
        'lib/${project.entrypoint.basename} is missing',
        hint: 'It is the file the host loads the project through, and it opens the app node. '
            'Copy it from a project `scribe create` wrote.',
      ),
    );
  }

  return findings;
}

List<Finding> _manifest(Project project) => <Finding>[
  for (final ManifestProblem problem in project.manifest.problems)
    Finding.problem(
      '$problem',
      hint: 'Fill `${problem.field}` in ${Project.configFileName}.',
    ),
];

/// The one secrets problem worth reporting: a store nothing can open.
///
/// A project without a `secrets.age` is fine — most are. A project with one and
/// no key is stuck, and the failure would otherwise only show up at the command
/// that needed a secret.
List<Finding> _secrets(Project project) {
  final SecretsStore store = SecretsStore.forProject(project);
  if (!store.exists || store.identityLines.isNotEmpty) return const <Finding>[];

  return <Finding>[
    Finding.problem(
      '${SecretsStore.fileName} is here, but no key opens it',
      hint: 'Put the key in ${store.keyFile.path}, or hand it through \$$kIdentityVariable.',
    ),
  ];
}
