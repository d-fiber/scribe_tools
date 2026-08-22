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

/// A version as the framework's `VERSION` file writes it: `major.minor.patch`.
///
/// Nothing else is accepted. `bump.py` is the only writer of that file and it
/// writes three whole numbers, so a line that does not parse is a file someone
/// edited by hand, and reading it as a version would be a guess.
class Version implements Comparable<Version> {
  /// Holds the version [major].[minor].[patch].
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
