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

enum ShellKind { bash, zsh, fish, powershell, cmd, unknown }

class Shell {
  const Shell({required this.kind, required this.executable, required this.profile});

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

  final ShellKind kind;
  final String executable;
  final File? profile;

  String get name => switch (kind) {
    ShellKind.bash => 'bash',
    ShellKind.zsh => 'zsh',
    ShellKind.fish => 'fish',
    ShellKind.powershell => 'PowerShell',
    ShellKind.cmd => 'cmd',
    ShellKind.unknown => 'your shell',
  };

  String exportLine(String directory) => switch (kind) {
    ShellKind.fish => 'fish_add_path $directory',
    ShellKind.powershell => '\$env:Path = "$directory;\$env:Path"',
    ShellKind.cmd => 'setx PATH "$directory;%PATH%"',
    _ => 'export PATH="$directory:\$PATH"',
  };

  String howToAdd(String directory) {
    final File? file = profile;
    if (file == null) return 'Add $directory to your PATH: ${exportLine(directory)}';

    return 'Add this to ${file.path}, then open a new terminal:\n  ${exportLine(directory)}';
  }

  @override
  String toString() => 'Shell($name)';
}
