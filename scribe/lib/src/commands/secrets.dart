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

import 'package:dage/dage.dart';
import 'package:scribe/src/commands/secrets/manifest_references.dart';
import 'package:scribe/src/commands/secrets/secret_edits.dart';
import 'package:scribe/src/commands/secrets/secrets_report.dart';
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/secrets.dart';

/// Lists, adds and removes the secrets a project carries in `secrets.age`.
class SecretsCommand extends ScribeCommand {
  SecretsCommand() {
    argParser
      ..addMultiOption(
        'set',
        abbr: 's',
        valueHelp: 'NAME=VALUE',
        help: 'Add or replace a secret. Repeat the flag to write several.',
      )
      ..addMultiOption(
        'unset',
        abbr: 'u',
        valueHelp: 'NAME',
        help: 'Remove a secret. Repeat the flag to remove several.',
      );
  }

  final SecretsReport _report = const SecretsReport();

  @override
  String get name => 'secrets';

  @override
  String get description => 'List, add or remove the secrets this project carries, encrypted.';

  @override
  String get invocation => 'scribe secrets [--set NAME=VALUE] [--unset NAME]';

  @override
  Future<ScribeCommandResult> runCommand() async {
    final SecretEdits edits = SecretEdits.parse(set: stringsArg('set'), unset: stringsArg('unset'));
    final SecretsStore store = SecretsStore.forProject(project);

    return edits.isEmpty ? _list(store) : _edit(store, edits);
  }

  /// Prints the names in [store], and the references the manifest has left unset.
  ///
  /// Returns a warning status when there are unset references: nothing is
  /// broken yet, but the next command to read one of them will fail.
  Future<ScribeCommandResult> _list(SecretsStore store) async {
    final Map<String, String> secrets = await store.read();
    final List<String> names = secrets.keys.toList()..sort();
    _report.stored(names);

    final List<String> unset = envReferencesIn(project.manifest.document).difference(names.toSet()).toList()..sort();
    if (unset.isEmpty) return const ScribeCommandResult.success();

    _report.unsetReferences(unset, configPath: project.config.path);
    return const ScribeCommandResult.warning();
  }

  /// Applies [edits] to [store] and reports what changed.
  ///
  /// The recipient is settled before the store is read so that a project
  /// without a `secrets.age` gets its key created once, not once per edit.
  Future<ScribeCommandResult> _edit(SecretsStore store, SecretEdits edits) async {
    final bool creating = !store.exists;
    final AgeRecipient recipient = await store.recipientOf();

    final Map<String, String> secrets = await store.read();
    final AppliedEdits applied = edits.applyTo(secrets);
    _report.nothingToRemove(applied.absent);

    await store.write(secrets, recipient: recipient);

    if (creating) _report.newKey(store);
    _report.changed(applied);

    return const ScribeCommandResult.success();
  }
}
