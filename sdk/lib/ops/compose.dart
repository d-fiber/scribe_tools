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

import '../core/commands/docker_compose.dart';
import 'hardware.dart';
import 'sizing.dart';
import 'sizing_rules.dart';
import '../core/paths/infra_files.dart';
import '../core/process.dart';

class Compose {
  static List<String>? _files;
  static List<String> _profiles = const <String>[];

  static Future<DockerCompose> docker() async => DockerCompose(
    await _rendered(),
    projectDirectory: InfraFiles.root.path,
    envFile: InfraFiles.tree.alchemy.ops.env.path,
    profiles: _profiles,
  );

  static Future<List<String>> _rendered() async {
    if (_files case final List<String> cached) return cached;

    final Hardware hardware = await Hardware.detect();
    final SizingRules rules = SizingRules(hardware);
    final List<File> rendered = await ComposeTemplates.render(Sizing.resolve(hardware));

    _profiles = rules.profiles.split(',').where((String p) => p.isNotEmpty).toList();
    return _files = rendered.map((File file) => file.path).toList();
  }

  static Future<void> run(DockerCompose command) =>
      streamPrivilegedCommand(command, cwd: InfraFiles.root.path);

  static Future<ProcessResult> capture(DockerCompose command) =>
      capturePrivilegedCommand(command, cwd: InfraFiles.root.path);

  static List<String> command(DockerCompose command) =>
      commandArgv(command, asPrivileged: true);
}
