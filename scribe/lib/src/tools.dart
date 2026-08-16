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

import 'package:scribe/src/base/logger.dart';
import 'package:scribe/src/base/terminal.dart';
import 'package:scribe/src/globals.dart' as globals;

/// A program this tool needs but does not ship.
class ExternalTool {
  const ExternalTool({
    required this.name,
    required this.executable,
    required this.purpose,
    required this.homepage,
    this.packages = const <String, String>{},
  });

  /// The name a human calls it by.
  final String name;

  /// The file looked for on `PATH`, which is not always [name].
  ///
  /// Node is the case that forces the distinction: it is installed as `node`
  /// and found by looking for `npm`.
  final String executable;

  /// What a command needs it for, shown to the user when it is missing.
  final String purpose;

  /// Where to get it by hand, shown when no package manager was found.
  final String homepage;

  /// The package name per package manager, for the managers that name it differently.
  final Map<String, String> packages;

  /// Whether [executable] is on `PATH`.
  bool get isInstalled => globals.os.has(executable);

  /// The package [manager] installs this tool under, [name] when it has no entry.
  String? packageFor(PackageManager manager) => packages[manager.name] ?? name;

  @override
  String toString() => name;
}

/// A system package manager this tool knows how to call.
class PackageManager {
  const PackageManager({
    required this.name,
    required this.executable,
    required this.install,
    this.needsPrivilege = false,
  });

  /// The managers looked for, in the order [detect] tries them.
  ///
  /// A machine can carry several, so this order is what picks the one used:
  /// the first present wins, and nothing looks further.
  static const List<PackageManager> known = <PackageManager>[
    PackageManager(name: 'homebrew', executable: 'brew', install: <String>['brew', 'install']),
    PackageManager(name: 'winget', executable: 'winget', install: <String>['winget', 'install', '--silent', '-e', '--id']),
    PackageManager(name: 'scoop', executable: 'scoop', install: <String>['scoop', 'install']),
    PackageManager(name: 'apt', executable: 'apt-get', install: <String>['apt-get', 'install', '-y'], needsPrivilege: true),
    PackageManager(name: 'dnf', executable: 'dnf', install: <String>['dnf', 'install', '-y'], needsPrivilege: true),
    PackageManager(name: 'pacman', executable: 'pacman', install: <String>['pacman', '-S', '--noconfirm'], needsPrivilege: true),
    PackageManager(name: 'apk', executable: 'apk', install: <String>['apk', 'add'], needsPrivilege: true),
  ];

  static PackageManager? detect() {
    for (final PackageManager manager in known) {
      if (globals.os.has(manager.executable)) return manager;
    }
    return null;
  }

  final String name;
  final String executable;
  final List<String> install;
  final bool needsPrivilege;

  List<String> commandFor(ExternalTool tool) => <String>[
    if (needsPrivilege) 'sudo',
    ...install,
    tool.packageFor(this)!,
  ];

  @override
  String toString() => name;
}

class ToolCatalog {
  const ToolCatalog._();

  static const ExternalTool deno = ExternalTool(
    name: 'deno',
    executable: 'deno',
    purpose: 'runs the host and the worker',
    homepage: 'https://docs.deno.com/runtime/getting_started/installation/',
    packages: <String, String>{'winget': 'DenoLand.Deno'},
  );

  static const ExternalTool npm = ExternalTool(
    name: 'node',
    executable: 'npm',
    purpose: 'builds the documentation portal',
    homepage: 'https://nodejs.org/en/download',
    packages: <String, String>{'apt': 'nodejs', 'winget': 'OpenJS.NodeJS'},
  );

  /// The engine the stack's services are run by.
  static const ExternalTool docker = ExternalTool(
    name: 'docker',
    executable: 'docker',
    purpose: 'runs the stack',
    homepage: 'https://docs.docker.com/get-started/get-docker/',
    packages: <String, String>{'homebrew': 'docker', 'apt': 'docker.io', 'winget': 'Docker.DockerDesktop'},
  );

  /// The version control the framework is fetched and read through.
  static const ExternalTool git = ExternalTool(
    name: 'git',
    executable: 'git',
    purpose: 'reads the repository',
    homepage: 'https://git-scm.com/downloads',
    packages: <String, String>{'winget': 'Git.Git'},
  );
}

/// What looks for the tools a command declared, and offers to install them.
class ToolProvisioner {
  const ToolProvisioner();

  /// Makes sure every one of [tools] is on `PATH`, installing what is missing.
  ///
  /// Nothing is installed without being agreed to, `sudo` included: [install]
  /// false explains and stops, a machine with no package manager only ever gets
  /// the homepage, and every other case is asked about one tool at a time.
  /// [assumeYes] carries `--yes` and answers for a script; without it, a run
  /// with no terminal to ask on declines instead of waiting for a human.
  ///
  /// A tool still missing afterwards is explained rather than thrown on. The
  /// command that follows fails on its own terms, which says more than a
  /// missing executable would.
  Future<void> ensure(List<ExternalTool> tools, {required bool install, required bool assumeYes}) async {
    final List<ExternalTool> missing = tools.where((ExternalTool tool) => !tool.isInstalled).toList();
    if (missing.isEmpty) return;

    final PackageManager? manager = PackageManager.detect();

    if (!install || manager == null) {
      _explain(missing, manager);
      return;
    }

    for (final ExternalTool tool in missing) {
      if (!assumeYes && !await _confirm(tool, manager)) {
        _explainOne(tool, manager);
        continue;
      }

      await _install(tool, manager);
    }

    final List<ExternalTool> stillMissing = missing.where((ExternalTool tool) => !tool.isInstalled).toList();
    if (stillMissing.isNotEmpty) _explain(stillMissing, manager);
  }

  Future<void> _install(ExternalTool tool, PackageManager manager) async {
    final List<String> command = manager.commandFor(tool);
    final Status status = globals.logger.startProgress('Installing ${tool.name} with ${manager.name}');

    try {
      final int code = await globals.processRunner.run(command);
      if (code != 0) {
        globals.logger.printWarning('${command.join(' ')} answered $code.');
      }
    } finally {
      status.stop();
    }
  }

  Future<bool> _confirm(ExternalTool tool, PackageManager manager) async {
    if (!globals.terminal.stdinHasTerminal) return false;

    final String answer = await globals.terminal.promptForCharInput(
      <String>['y', 'n'],
      write: (String message) => globals.logger.printStatus(message, newline: false),
      prompt: '${tool.name} is missing — install it with ${manager.name}?',
      defaultChoiceIndex: 0,
    );

    return answer == 'y';
  }

  void _explain(List<ExternalTool> missing, PackageManager? manager) {
    globals.logger.printStatus('');
    globals.logger.printStatus(
      '${missing.length} tool${missing.length == 1 ? '' : 's'} this command needs ${missing.length == 1 ? 'is' : 'are'} missing:',
      emphasis: true,
    );

    for (final ExternalTool tool in missing) {
      _explainOne(tool, manager);
    }

    globals.logger.printStatus('');
  }

  void _explainOne(ExternalTool tool, PackageManager? manager) {
    globals.logger.printStatus('  ${tool.name} — ${tool.purpose}', color: TerminalColor.yellow);

    if (manager != null) {
      globals.logger.printStatus('    ${manager.commandFor(tool).join(' ')}');
      return;
    }

    globals.logger.printStatus('    ${tool.homepage}');
  }
}
