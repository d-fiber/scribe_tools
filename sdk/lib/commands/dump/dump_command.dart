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

import 'package:path/path.dart' as p;

import '../../core/commands/base/cp.dart';
import '../../core/commands/base/rm.dart';
import '../../core/commands/psql/pg_dump.dart';
import '../../core/commands/tar.dart';
import '../../core/paths/infra_files.dart';
import '../../core/process.dart';
import '../../ops/compose.dart';
import '../../ops/project_command.dart';

String _timestamp() {
  final DateTime now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

class DumpCommand extends ProjectCommand {
  DumpCommand() : super(logScope: 'dump');

  @override
  final String name = 'dump';

  @override
  final String description = 'Dump the database roles, schema, data and storage.';

  Future<void> _pgDump(File dest, PgDump Function(PgDump dump) configure) async {
    final PgDump dump = configure(
      PgDump()
        ..user('postgres')
        ..noPassword(),
    );
    return streamPrivilegedCommandToFile(
      (await Compose.docker())
        ..exec()
        ..noTty()
        ..service('db')
        ..command(commandArgv(dump)),
      dest,
      cwd: InfraFiles.root.path,
    );
  }

  void _section(String message) => print('\n▶ $message');

  @override
  Future<void> runCommand() async {
    final ProcessResult running = await Compose.capture(
      (await Compose.docker())
        ..ps()
        ..quiet(),
    );
    if ((running.stdout as String).trim().isEmpty) {
      log.error('Containers are not running. Run `install` first.');
    }

    final String ts = _timestamp();
    final Directory dumpsDir = Directory(p.join(InfraFiles.root.path, 'dumps'));
    final Directory out = Directory(p.join(dumpsDir.path, ts));
    out.createSync(recursive: true);

    _section('Dumping roles');
    await _pgDump(
      File(p.join(out.path, 'roles.sql')),
      (PgDump dump) => dump
        ..rolesOnly()
        ..noRolePasswords()
        ..database('postgres'),
    );
    log.info('Roles    → roles.sql');

    _section('Dumping schema');
    await _pgDump(
      File(p.join(out.path, 'schema.sql')),
      (PgDump dump) => dump
        ..schemaOnly()
        ..noOwner()
        ..noAcl()
        ..database('postgres'),
    );
    log.info('Schema   → schema.sql');

    _section('Dumping data');
    await _pgDump(
      File(p.join(out.path, 'data.sql')),
      (PgDump dump) => dump
        ..dataOnly()
        ..useCopy()
        ..noOwner()
        ..noAcl()
        ..database('postgres'),
    );
    log.info('Data     → data.sql');

    _section('Copying storage files');
    final Directory storage = InfraFiles.tree.scribe.storage.directory;
    if (storage.existsSync() && storage.listSync().isNotEmpty) {
      await streamCommand(
        Cp()
          ..recursive()
          ..source(storage.path)
          ..destination(p.join(out.path, 'storage')),
      );
      log.info('Storage  → storage/');
    } else {
      log.info('Storage is empty skipped.');
    }

    _section('Compressing');
    final String archivePath = p.join(dumpsDir.path, '$ts.tar.gz');
    await streamCommand(
      Tar()
        ..create()
        ..gzip()
        ..file(archivePath)
        ..directory(dumpsDir.path)
        ..add(ts),
    );
    await streamCommand(
      Rm()
        ..recursive()
        ..force()
        ..path(out.path),
    );
    log.info('Archive  → dumps/$ts.tar.gz');

    print('');
    log.info('Done! Dump saved to: dumps/$ts.tar.gz');
  }
}
