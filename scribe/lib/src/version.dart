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

/// A version as the framework's `VERSION` file writes it: `major.minor.patch`.
///
/// Nothing else is accepted. `bump.py` is the only writer of that file and it
/// writes three whole numbers, so a line that does not parse is a file someone
/// edited by hand, and reading it as a version would be a guess.
class Version implements Comparable<Version> {
  const Version(this.major, this.minor, this.patch);

  /// [raw] read as a version, or null when it is not one.
  ///
  /// Surrounding whitespace is dropped, since this almost always comes from a
  /// file that ends with a newline.
  static Version? tryParse(String raw) {
    final List<String> parts = raw.trim().split('.');
    if (parts.length != 3) return null;

    final List<int> numbers = <int>[];
    for (final String part in parts) {
      final int? number = int.tryParse(part);
      if (number == null || number < 0) return null;
      numbers.add(number);
    }

    return Version(numbers[0], numbers[1], numbers[2]);
  }

  /// The first number, the one that changes when a contract breaks.
  final int major;

  /// The second number.
  final int minor;

  /// The third number.
  final int patch;

  /// Whether this version comes after [other].
  bool isNewerThan(Version other) => compareTo(other) > 0;

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
