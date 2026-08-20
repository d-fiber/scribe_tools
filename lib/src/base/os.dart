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

import 'package:scribe_tools/src/base/platform.dart';

/// A system and processor pair the tool can be running on.
enum HostPlatform {
  darwinArm64('macOS', 'arm64'),
  darwinX64('macOS', 'x86_64'),
  linuxArm64('Linux', 'arm64'),
  linuxX64('Linux', 'x86_64'),
  windowsArm64('Windows', 'arm64'),
  windowsX64('Windows', 'x86_64');

  const HostPlatform(this.systemName, this.architecture);

  /// The system's name as a human writes it.
  final String systemName;

  /// The processor family, named as a release asset names it.
  final String architecture;

  @override
  String toString() => '$systemName $architecture';
}

/// What the tool needs from the host system beyond files and processes.
abstract class OperatingSystemUtils {
  const OperatingSystemUtils();

  /// Creates the implementation that matches [platform].
  factory OperatingSystemUtils.forPlatform({required Platform platform, required FileSystem fileSystem}) {
    if (platform.isWindows) return WindowsUtils(platform: platform, fileSystem: fileSystem);
    if (platform.isMacOS) return MacOsUtils(platform: platform, fileSystem: fileSystem);
    return LinuxUtils(platform: platform, fileSystem: fileSystem);
  }

  /// The system this reads its environment from.
  Platform get platform;

  /// The file system a candidate executable is looked for on.
  FileSystem get fileSystem;

  /// The system and processor this is running on.
  HostPlatform get hostPlatform;

  /// The character `PATH` is split on.
  String get pathVarSeparator;

  /// The suffixes an executable may carry, a single empty one outside Windows.
  List<String> get executableSuffixes;

  /// The first [executable] found on `PATH`, or null.
  ///
  /// No process is started: `PATH` is walked here. That is more portable than
  /// asking `which` or `where`, and it is what lets a test answer from a memory
  /// file system.
  File? which(String executable) => whichAll(executable).firstOrNull;

  /// Every [executable] found on `PATH`, in the order `PATH` names the directories.
  List<File> whichAll(String executable) {
    final String? path = platform.environment['PATH'];
    if (path == null || path.isEmpty) return const <File>[];

    final List<File> found = <File>[];

    for (final String entry in path.split(pathVarSeparator)) {
      if (entry.isEmpty) continue;

      for (final String suffix in executableSuffixes) {
        final File candidate = fileSystem.file(p.join(entry, '$executable$suffix'));
        if (candidate.existsSync()) found.add(candidate);
      }
    }

    return found;
  }

  /// Whether [executable] is anywhere on `PATH`.
  bool has(String executable) => which(executable) != null;

  /// The processor family this is running on.
  String get architecture => hostPlatform.architecture;
}

/// The [OperatingSystemUtils] of a system with a POSIX `PATH`.
class PosixUtils extends OperatingSystemUtils {
  const PosixUtils({required this.platform, required this.fileSystem});

  @override
  final Platform platform;

  @override
  final FileSystem fileSystem;

  @override
  String get pathVarSeparator => ':';

  @override
  List<String> get executableSuffixes => const <String>[''];

  @override
  HostPlatform get hostPlatform => HostPlatform.linuxX64;
}

/// The [OperatingSystemUtils] of macOS.
class MacOsUtils extends PosixUtils {
  const MacOsUtils({required super.platform, required super.fileSystem});

  @override
  HostPlatform get hostPlatform =>
      _isArm(platform) ? HostPlatform.darwinArm64 : HostPlatform.darwinX64;
}

/// The [OperatingSystemUtils] of Linux.
class LinuxUtils extends PosixUtils {
  const LinuxUtils({required super.platform, required super.fileSystem});

  @override
  HostPlatform get hostPlatform => _isArm(platform) ? HostPlatform.linuxArm64 : HostPlatform.linuxX64;
}

/// The [OperatingSystemUtils] of Windows, where `PATH` alone does not name a file.
class WindowsUtils extends OperatingSystemUtils {
  const WindowsUtils({required this.platform, required this.fileSystem});

  @override
  final Platform platform;

  @override
  final FileSystem fileSystem;

  @override
  String get pathVarSeparator => ';';

  /// The extensions `PATHEXT` declares, lowercased, or the Windows default when it is unset.
  @override
  List<String> get executableSuffixes {
    final String pathExt = platform.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD';
    return pathExt.split(';').map((String suffix) => suffix.toLowerCase()).toList();
  }

  @override
  HostPlatform get hostPlatform => _isArm(platform) ? HostPlatform.windowsArm64 : HostPlatform.windowsX64;
}

bool _isArm(Platform platform) {
  final String reported = <String>[
    platform.environment['PROCESSOR_ARCHITECTURE'] ?? '',
    platform.environment['HOSTTYPE'] ?? '',
    platform.version,
  ].join(' ').toLowerCase();

  return reported.contains('arm') || reported.contains('aarch64');
}

extension on List<File> {
  File? get firstOrNull => isEmpty ? null : first;
}
