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

import 'package:interact/interact.dart';

import '../../ops/compose.dart';
import '../../ops/env_file.dart';
import '../../ops/project_command.dart';
import '../../ops/secrets.dart';
import '../gen/code/generators/config/kong.dart';

const List<String> _fields = <String>['ADMIN_APP_KEYS', 'APP_KEYS'];

class KeysCommand extends ProjectCommand {
  KeysCommand() : super(logScope: 'keys');

  @override
  final String name = 'keys';

  @override
  final String description = 'Add or remove ADMIN_APP_KEYS / APP_KEYS interactively.';

  @override
  Future<void> runCommand() async {
    while (true) {
      final String? field = _chooseField();
      if (field == null) break;

      List<String> keys = _readKeys(field);
      _showKeys(field, keys);

      final int action = Select(
        prompt: 'What do you want to do?',
        options: <String>['Add a new key', 'Remove a key', 'Done'],
      ).interact();

      if (action == 0) {
        keys = await _addKey(field, keys);
      } else if (action == 1) {
        keys = await _removeKey(field, keys);
      }
    }

    print('');
    log.info('Done.');
  }

  String? _chooseField() {
    final int choice = Select(
      prompt: 'Which key set do you want to manage?',
      options: <String>[..._fields, 'Cancel'],
    ).interact();
    return choice == _fields.length ? null : _fields[choice];
  }

  List<String> _readKeys(String field) =>
      EnvFile.read(field).split(',').map((String k) => k.trim()).where((String k) => k.isNotEmpty).toList();

  void _writeKeys(String field, List<String> keys) => EnvFile.write(field, keys.join(','));

  String _mask(String key) => key.length <= 12 ? key : '${key.substring(0, 6)}…${key.substring(key.length - 4)}';

  void _showKeys(String field, List<String> keys) {
    print('');
    print('$field ${keys.length} key(s):');
    if (keys.isEmpty) print('  (none)');
    for (int i = 0; i < keys.length; i++) {
      print('  ${i + 1}. ${_mask(keys[i])}');
    }
  }

  Future<void> _restartKong() async {
    log.info('Restarting Kong to apply the new keys...');
    await Compose.run(
      (await Compose.docker())
        ..restart()
        ..service('kong'),
    );
  }

  Future<List<String>> _addKey(String field, List<String> keys) async {
    final String newKey = Secrets.randBase64(32);
    final List<String> updated = <String>[...keys, newKey];
    _writeKeys(field, updated);
    await generateKong();
    await _restartKong();
    print('');
    log.info('Added a new key to $field:');
    print('  $newKey');
    log.warn(
      "Redeploy 'functions'/'api' to apply, then update the matching "
      'client before removing any old key.',
    );
    return updated;
  }

  Future<List<String>> _removeKey(String field, List<String> keys) async {
    if (keys.isEmpty) {
      log.warn('No keys to remove.');
      return keys;
    }

    if (keys.length == 1) {
      log.warn(
        '$field has only one key left removing it locks out every client '
        'until a new one is added and deployed.',
      );
    }

    final int choice = Select(
      prompt: 'Number of the key to remove',
      options: <String>[for (final String key in keys) _mask(key), 'Cancel'],
    ).interact();
    if (choice == keys.length) {
      log.info('Aborted.');
      return keys;
    }

    final bool confirmed = Confirm(
      prompt: 'Remove key ${_mask(keys[choice])} from $field?',
      defaultValue: false,
    ).interact();
    if (!confirmed) {
      log.info('Aborted.');
      return keys;
    }

    final String removed = keys[choice];
    final List<String> updated = <String>[...keys]..removeAt(choice);
    _writeKeys(field, updated);
    await generateKong();
    await _restartKong();
    log.info('Removed key ${_mask(removed)} from $field.');
    log.warn("Redeploy 'functions'/'api' to apply.");
    return updated;
  }
}
