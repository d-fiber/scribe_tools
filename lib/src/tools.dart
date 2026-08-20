// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:scribe_tools/src/base/logger.dart';
import 'package:scribe_tools/src/base/terminal.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// A program this tool needs but does not ship.
class ExternalTool {
  /// Declares a tool by [name], found on `PATH` as [executable].
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
  /// Declares a manager found as [executable], installing with [install].
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
    PackageManager(
      name: 'winget',
      executable: 'winget',
      install: <String>['winget', 'install', '--silent', '-e', '--id'],
    ),
    PackageManager(name: 'scoop', executable: 'scoop', install: <String>['scoop', 'install']),
    PackageManager(
      name: 'apt',
      executable: 'apt-get',
      install: <String>['apt-get', 'install', '-y'],
      needsPrivilege: true,
    ),
    PackageManager(name: 'dnf', executable: 'dnf', install: <String>['dnf', 'install', '-y'], needsPrivilege: true),
    PackageManager(
      name: 'pacman',
      executable: 'pacman',
      install: <String>['pacman', '-S', '--noconfirm'],
      needsPrivilege: true,
    ),
    PackageManager(name: 'apk', executable: 'apk', install: <String>['apk', 'add'], needsPrivilege: true),
  ];

  /// The first of [known] that this machine carries, null when it carries none.
  static PackageManager? detect() {
    for (final PackageManager manager in known) {
      if (globals.os.has(manager.executable)) return manager;
    }
    return null;
  }

  /// The name this manager goes by, and the key [ExternalTool.packages] uses.
  final String name;

  /// The file looked for on `PATH` to know this manager is here.
  final String executable;

  /// The words that install a package, up to but not including its name.
  final List<String> install;

  /// Whether installing through this manager has to go through `sudo`.
  final bool needsPrivilege;

  /// The full command line that installs [tool] through this manager.
  List<String> commandFor(ExternalTool tool) => <String>[
    if (needsPrivilege) 'sudo',
    ...install,
    tool.packageFor(this)!,
  ];

  @override
  String toString() => name;
}

/// The programs the CLI knows how to look for and offer to install.
class ToolCatalog {
  const ToolCatalog._();

  /// The runtime the host and the worker are run by.
  static const ExternalTool deno = ExternalTool(
    name: 'deno',
    executable: 'deno',
    purpose: 'runs the host and the worker',
    homepage: 'https://docs.deno.com/runtime/getting_started/installation/',
    packages: <String, String>{'winget': 'DenoLand.Deno'},
  );

  /// The runtime the documentation portal is built with.
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
  /// Holds nothing: every run is told what it is looking for.
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
      prompt: '${tool.name} is missing. Install it with ${manager.name}?',
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
    globals.logger.printStatus('  ${tool.name}: ${tool.purpose}', color: TerminalColor.yellow);

    if (manager != null) {
      globals.logger.printStatus('    ${manager.commandFor(tool).join(' ')}');
      return;
    }

    globals.logger.printStatus('    ${tool.homepage}');
  }
}
