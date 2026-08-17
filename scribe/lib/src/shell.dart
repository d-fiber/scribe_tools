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
import 'package:path/path.dart' as p;

import 'package:scribe/src/base/platform.dart';

/// A shell whose profile syntax this tool knows.
///
/// [unknown] is a POSIX shell that is none of the others, and it is treated as
/// bash: the export line and the profile path are the ones bash uses.
enum ShellKind { bash, zsh, fish, powershell, cmd, unknown }

/// The shell the user came from, and where its profile lives.
///
/// This is the only place a shell matters. An external command is started with
/// an argument list and never through `sh -c`, so nothing is quoted and no
/// shell has to be installed. See `ProcessRunner`. What is left is telling the
/// user which line to add to which file when a binary lands outside `PATH`.
class Shell {
  const Shell({required this.kind, required this.executable, required this.profile});

  /// The shell [platform] says the user came from.
  ///
  /// Outside Windows it is read from `SHELL`; on Windows the presence of
  /// `PSModulePath` separates PowerShell from cmd. [profile] comes back null
  /// when the environment names no home directory, since there is then no file
  /// to point at.
  ///
  /// `ZDOTDIR` and `XDG_CONFIG_HOME` are honoured, so a user who moved their
  /// configuration is not told to edit a file they do not use.
  static Shell detect({required Platform platform, required FileSystem fileSystem}) {
    if (platform.isWindows) return _windows(platform, fileSystem);

    final String executable = platform.environment['SHELL'] ?? '';
    final String name = executable.isEmpty ? '' : p.basename(executable);
    final String home = platform.environment['HOME'] ?? '';

    final ShellKind kind = switch (name) {
      'zsh' => ShellKind.zsh,
      'bash' => ShellKind.bash,
      'fish' => ShellKind.fish,
      _ => ShellKind.unknown,
    };

    return Shell(
      kind: kind,
      executable: executable,
      profile: home.isEmpty ? null : _posixProfile(kind, home, platform, fileSystem),
    );
  }

  static Shell _windows(Platform platform, FileSystem fileSystem) {
    final bool powershell = (platform.environment['PSModulePath'] ?? '').isNotEmpty;
    final String? profile = platform.environment['USERPROFILE'];

    return Shell(
      kind: powershell ? ShellKind.powershell : ShellKind.cmd,
      executable: powershell ? 'powershell' : 'cmd',
      profile: powershell && profile != null
          ? fileSystem.file(p.join(profile, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'))
          : null,
    );
  }

  static File _posixProfile(ShellKind kind, String home, Platform platform, FileSystem fileSystem) => switch (kind) {
    ShellKind.zsh => fileSystem.file(p.join(_zshHome(home, platform), '.zshrc')),
    ShellKind.fish => fileSystem.file(p.join(_configHome(home, platform), 'fish', 'config.fish')),
    _ => fileSystem.file(p.join(home, '.bashrc')),
  };

  static String _zshHome(String home, Platform platform) {
    final String? zdot = platform.environment['ZDOTDIR'];
    return zdot == null || zdot.isEmpty ? home : zdot;
  }

  static String _configHome(String home, Platform platform) {
    final String? xdg = platform.environment['XDG_CONFIG_HOME'];
    return xdg == null || xdg.isEmpty ? p.join(home, '.config') : xdg;
  }

  /// Which shell this is, and so which syntax [exportLine] writes.
  final ShellKind kind;

  /// The shell's own executable, as the environment named it.
  final String executable;

  /// The file a line has to be added to for it to survive a new terminal.
  ///
  /// Null when the environment names no home directory, and on Windows outside
  /// PowerShell, where cmd has no profile to write to.
  final File? profile;

  /// The shell's name as a human writes it, or `your shell` when it is unknown.
  String get name => switch (kind) {
    ShellKind.bash => 'bash',
    ShellKind.zsh => 'zsh',
    ShellKind.fish => 'fish',
    ShellKind.powershell => 'PowerShell',
    ShellKind.cmd => 'cmd',
    ShellKind.unknown => 'your shell',
  };

  /// The line that puts [directory] on `PATH`, in this shell's own syntax.
  String exportLine(String directory) => switch (kind) {
    ShellKind.fish => 'fish_add_path $directory',
    ShellKind.powershell => '\$env:Path = "$directory;\$env:Path"',
    ShellKind.cmd => 'setx PATH "$directory;%PATH%"',
    _ => 'export PATH="$directory:\$PATH"',
  };

  /// The sentence telling the user how to put [directory] on their `PATH`.
  ///
  /// The file is named when there is one to name. Nothing is written: editing
  /// a user's profile without being asked is a surprise this tool does not make.
  String howToAdd(String directory) {
    final File? file = profile;
    if (file == null) return 'Add $directory to your PATH: ${exportLine(directory)}';

    return 'Add this to ${file.path}, then open a new terminal:\n  ${exportLine(directory)}';
  }

  @override
  String toString() => 'Shell($name)';
}
