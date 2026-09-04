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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:scribe_tools/src/base/common.dart';
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
  /// Declares a manager found as [executable], installing with [installCommand].
  const PackageManager({
    required this.name,
    required this.executable,
    required this.installCommand,
    this.needsPrivilege = false,
  });

  /// The managers looked for, in the order [detect] tries them.
  ///
  /// A machine can carry several, so this order is what picks the one used:
  /// the first present wins, and nothing looks further.
  static const List<PackageManager> known = <PackageManager>[
    PackageManager(name: 'homebrew', executable: 'brew', installCommand: _brewInstall),
    PackageManager(name: 'winget', executable: 'winget', installCommand: _wingetInstall),
    PackageManager(name: 'scoop', executable: 'scoop', installCommand: _scoopInstall),
    PackageManager(name: 'apt', executable: 'apt-get', installCommand: _aptInstall, needsPrivilege: true),
    PackageManager(name: 'dnf', executable: 'dnf', installCommand: _dnfInstall, needsPrivilege: true),
    PackageManager(name: 'pacman', executable: 'pacman', installCommand: _pacmanInstall, needsPrivilege: true),
    PackageManager(name: 'apk', executable: 'apk', installCommand: _apkInstall, needsPrivilege: true),
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

  /// The command that installs a package, given its name.
  final ShellCommand Function(String package) installCommand;

  /// Whether installing through this manager has to go through `sudo`.
  final bool needsPrivilege;

  /// The full command line that installs [tool] through this manager.
  List<String> commandFor(ExternalTool tool) =>
      commandArgv(installCommand(tool.packageFor(this)!), asPrivileged: needsPrivilege);

  @override
  String toString() => name;
}

ShellCommand _brewInstall(String package) => Brew.install().arg(package);
ShellCommand _wingetInstall(String package) => Winget.install().silent().exact().id(package);
ShellCommand _scoopInstall(String package) => Scoop.install().arg(package);
ShellCommand _aptInstall(String package) => AptGet.install().assumeYes().arg(package);
ShellCommand _dnfInstall(String package) => Dnf.install().assumeYes().arg(package);
ShellCommand _pacmanInstall(String package) => Pacman.sync().noconfirm().arg(package);
ShellCommand _apkInstall(String package) => Apk.add().arg(package);

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

  /// The second runtime a package's own tooling may run its TypeScript on, named under
  /// `environment.runtime:` in its `package.yaml`.
  static const ExternalTool bun = ExternalTool(
    name: 'bun',
    executable: 'bun',
    purpose: "runs a package's suite and schema/ when its manifest asks for it over deno",
    homepage: 'https://bun.sh/docs/installation',
    packages: <String, String>{'homebrew': 'oven-sh/bun/bun', 'winget': 'Oven-sh.Bun'},
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

  /// What creates the resources a target places outside the stack.
  static const ExternalTool tofu = ExternalTool(
    name: 'opentofu',
    executable: 'tofu',
    purpose: 'creates the resources a target does not put in a container',
    homepage: 'https://opentofu.org/docs/intro/install/',
    packages: <String, String>{'homebrew': 'opentofu', 'winget': 'OpenTofu.Tofu', 'apk': 'opentofu'},
  );

  /// What reaches the host a deployment goes to.
  static const ExternalTool ssh = ExternalTool(
    name: 'ssh',
    executable: 'ssh',
    purpose: 'reaches the host a target names',
    homepage: 'https://www.openssh.com/portable.html',
    packages: <String, String>{'homebrew': 'openssh', 'apt': 'openssh-client', 'apk': 'openssh-client'},
  );

  /// What carries the stack to that host.
  static const ExternalTool rsync = ExternalTool(
    name: 'rsync',
    executable: 'rsync',
    purpose: 'ships the stack to the host a target names',
    homepage: 'https://rsync.samba.org/',
  );

  /// What `upgrade` reads a release through, checking for one and fetching it.
  static const ExternalTool curl = ExternalTool(
    name: 'curl',
    executable: 'curl',
    purpose: 'checks for and downloads a new release of the tool or the dashboard',
    homepage: 'https://curl.se/download.html',
    packages: <String, String>{'winget': 'cURL.cURL'},
  );

  /// Every tool the CLI knows about, which is what `doctor` walks.
  ///
  /// A tool that a command needs and this list forgets is a tool nobody is told
  /// about until the command fails on it, so the list is the catalogue itself
  /// rather than a copy of it kept somewhere else.
  static const List<ExternalTool> all = <ExternalTool>[deno, bun, npm, docker, git, tofu, ssh, rsync, curl];

  /// The tools no command can work without, which every run is stopped for.
  ///
  /// The rest are asked for where they are used: `tofu` matters to a target that
  /// provisions and to no other, `ssh` and `rsync` to one that deploys
  /// elsewhere, and `node` to the documentation. Demanding them of every run
  /// would stop a local `run` on a program it never calls, which is what a
  /// continuous integration runner met first.
  static const List<ExternalTool> essential = <ExternalTool>[deno, docker, git];

  /// Whether [tool] is one a run is stopped for when it is missing.
  static bool isEssential(ExternalTool tool) => essential.contains(tool);
}

/// What looks for the tools a command declared, and offers to install them.
class ToolProvisioner {
  /// Holds nothing: every run is told what it is looking for.
  const ToolProvisioner();

  /// Refuses the run when [tool] is not on `PATH`, naming what installs it.
  ///
  /// It is the guard for a tool a command needs only sometimes: `tofu` matters
  /// to a target that provisions and to no other, and demanding it of everybody
  /// would make a local run wait on something it never calls.
  void require(ExternalTool tool, {required String reason}) {
    if (tool.isInstalled) return;

    final PackageManager? manager = PackageManager.detect();

    throwToolExit(
      '${tool.name} is missing, and $reason.\n'
      '${manager == null ? 'Install it from ${tool.homepage}.' : 'Run `${manager.commandFor(tool).join(' ')}` to install it.'}\n'
      '\n'
      'scribe doctor    says what this machine is missing, --rescue installs it',
    );
  }

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
    final Status status = globals.logger.startProgress('Installing ${tool.name} with ${manager.name}...');

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
    globals.logger.printStatus('scribe doctor    says what this machine is missing, --rescue installs it');
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
