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
import 'package:scribe/src/base/common.dart';
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/runner/scribe_command.dart';
import 'package:scribe/src/scribe_manifest.dart';
import 'package:scribe/src/secrets.dart';

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

  @override
  String get name => 'secrets';

  @override
  String get description => 'List, add or remove the secrets this project carries, encrypted.';

  @override
  String get invocation => 'scribe secrets [--set NAME=VALUE] [--unset NAME]';

  @override
  Future<ScribeCommandResult> runCommand() async {
    final List<SecretAssignment> additions =
        stringsArg('set').map(SecretAssignment.parse).toList();
    final List<String> removals = stringsArg('unset').map(_validName).toList();

    final SecretsStore store = SecretsStore.forProject(project);

    if (additions.isEmpty && removals.isEmpty) return _list(store);

    final bool creating = !store.exists;
    final AgeRecipient recipient = await store.recipientOf();
    final Map<String, String> secrets = await store.read();

    final List<String> removed = <String>[];
    for (final String name in removals) {
      if (secrets.remove(name) == null) {
        globals.logger.printWarning('$name was not set, nothing to remove.');
        continue;
      }
      removed.add(name);
    }
    for (final SecretAssignment addition in additions) {
      secrets[addition.name] = addition.value;
    }

    await store.write(secrets, recipient: recipient);

    if (creating) _announceNewKey(store);

    for (final SecretAssignment addition in additions) {
      globals.logger.printStatus('${globals.terminal.successMark} set ${addition.name}');
    }
    for (final String name in removed) {
      globals.logger.printStatus('${globals.terminal.successMark} unset $name');
    }

    return const ScribeCommandResult.success();
  }

  Future<ScribeCommandResult> _list(SecretsStore store) async {
    final Map<String, String> secrets = await store.read();
    final List<String> names = secrets.keys.toList()..sort();

    if (names.isEmpty) {
      globals.logger.printStatus('No secret yet. Add one with `scribe secrets --set NAME=VALUE`.');
    }
    for (final String name in names) {
      globals.logger.printStatus('  $name');
    }

    final List<String> missing = _referencedButUnset(names);
    if (missing.isEmpty) return const ScribeCommandResult.success();

    globals.logger.printStatus('');
    globals.logger.printStatus('${project.config.path} reads secrets nobody has set:', emphasis: true);
    for (final String name in missing) {
      globals.logger.printStatus('  $name', color: TerminalColor.yellow);
    }

    return const ScribeCommandResult.warning();
  }

  List<String> _referencedButUnset(List<String> known) {
    final Set<String> referenced = <String>{};

    void walk(Object? node) {
      if (node is Map) {
        node.values.forEach(walk);
        return;
      }
      if (node is List) {
        node.forEach(walk);
        return;
      }
      if (node is! String) return;

      if (envReference.firstMatch(node.trim()) case final RegExpMatch reference) {
        referenced.add(reference.namedGroup('name')!);
      }
    }

    walk(project.manifest.document);

    return (referenced.difference(known.toSet()).toList())..sort();
  }

  void _announceNewKey(SecretsStore store) {
    globals.logger.printStatus('');
    globals.logger.printStatus('A new key was created in ${store.keyFile.path}.', emphasis: true);
    globals.logger.printStatus(
      'It is the only thing that opens ${store.file.path}. Back it up, and never commit it.',
      color: TerminalColor.yellow,
    );
    globals.logger.printStatus('');
  }

  String _validName(String raw) {
    final String name = raw.trim();
    if (secretName.hasMatch(name)) return name;

    throwUsageError(
      '"$name" is not a secret name — use uppercase letters, digits and underscore, starting with a letter.',
      command: name,
    );
  }
}
