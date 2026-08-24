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

/// What a package may be called.
///
/// The name becomes three things at once: the directory, the segment of an
/// import specifier and the key a project writes in its configuration. Anything
/// that cannot sit in all three cannot name a package.
final RegExp _accepted = RegExp(r'^[a-z]+(_[a-z]+)*$');

/// The names the framework answers to itself, which no package may take.
///
/// Each one already resolves to something else in an import specifier or in a
/// generated directory, so a package taking one would be reachable under a name
/// that already points elsewhere.
const List<String> kReservedPackageNames = <String>['app', 'core', 'engine', 'generated', 'scribe'];

/// Whether [name] is spelled the way a package name has to be spelled.
bool isValidPackageName(String name) => _accepted.hasMatch(name);

/// What is wrong with [name], in the sentence a caller prints, or null.
///
/// The sentence is built here rather than at each call site so that the rule and
/// its wording move together.
String? packageNameProblem(String name) {
  if (!isValidPackageName(name)) {
    return '"$name" cannot name a package. Use lowercase letters and single underscores, '
        'starting and ending with a letter, as in "dynamic_links".';
  }

  if (kReservedPackageNames.contains(name)) {
    return '"$name" is a name the framework keeps for itself. The reserved ones are '
        '${kReservedPackageNames.join(', ')}.';
  }

  return null;
}
