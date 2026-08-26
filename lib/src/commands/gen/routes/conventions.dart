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

/// The naming rules a route file has to follow to be found.
///
/// Nothing here reads the disk. These are the rules the scanner and the emitter
/// both apply, kept in one place so a name cannot mean one thing on the way in
/// and another on the way out.
class Conventions {
  const Conventions._();

  /// The extension a route file carries.
  static const String sourceExtension = '.ts';

  /// The name a file takes to answer on the directory itself.
  static const String indexName = 'index';

  /// The name of the file that wraps every route under its directory.
  static const String middlewareName = '_middleware';

  /// The name the node declaration used to go by, kept to recognise it and refuse it.
  static const String nodeName = '_node';

  /// The name of the file that declares where a directory's logs go.
  static const String logName = '_logs';

  /// What a name starts with when it is not to be served.
  static const String privatePrefix = '_';

  /// Whether [basename] is a file the scanner reads at all.
  static bool isSource(String basename) => basename.endsWith(sourceExtension);

  /// Whether [basename] is a `_middleware.ts`, which wraps the routes below it.
  static bool isMiddleware(String basename) => basename == '$middlewareName$sourceExtension';

  /// Whether [basename] is a `_node.ts`, which no longer declares anything.
  static bool isObsoleteNode(String basename) => basename == '$nodeName$sourceExtension';

  /// Whether [basename] is a `_logs.ts`, the sink a node or the project declares.
  static bool isLog(String basename) => basename == '$logName$sourceExtension';

  /// Whether [basename] is kept out of the served surface by its leading underscore.
  static bool isPrivate(String basename) => basename.startsWith(privatePrefix);

  /// Whether [basename] becomes a route of its own.
  static bool isRoutable(String basename) => isSource(basename) && !isPrivate(basename);

  /// [basename] without the extension every route file carries.
  static String withoutExtension(String basename) => basename.substring(0, basename.length - sourceExtension.length);

  /// [name] as the router spells it, `[id]` becoming `:id`.
  ///
  /// A directory in brackets is how the tree writes a parameter, and a colon is
  /// how the router reads one. Anything else comes back untouched.
  static String segment(String name) {
    if (name.startsWith('[') && name.endsWith(']')) {
      return ':${name.substring(1, name.length - 1)}';
    }
    return name;
  }

  /// The route [name] answers on, under the route [prefix] answers on.
  ///
  /// The root is `/`, so joining onto it must not leave `//` behind.
  static String join(String prefix, String name) {
    final String encoded = segment(name);
    return prefix == '/' ? '/$encoded' : '$prefix/$encoded';
  }
}
