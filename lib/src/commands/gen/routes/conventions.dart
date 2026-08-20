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

class Conventions {
  const Conventions._();

  static const String sourceExtension = '.ts';
  static const String indexName = 'index';
  static const String middlewareName = '_middleware';
  static const String nodeName = '_node';
  static const String logName = '_log';
  static const String privatePrefix = '_';

  static bool isSource(String basename) => basename.endsWith(sourceExtension);

  static bool isMiddleware(String basename) =>
      basename == '$middlewareName$sourceExtension';

  static bool isObsoleteNode(String basename) =>
      basename == '$nodeName$sourceExtension';

  /// Whether [basename] is a `_log.ts`, the sink a node or the project declares.
  static bool isLog(String basename) => basename == '$logName$sourceExtension';

  static bool isPrivate(String basename) => basename.startsWith(privatePrefix);

  static bool isRoutable(String basename) => isSource(basename) && !isPrivate(basename);

  static String withoutExtension(String basename) =>
      basename.substring(0, basename.length - sourceExtension.length);

  static String segment(String name) {
    if (name.startsWith('[') && name.endsWith(']')) {
      return ':${name.substring(1, name.length - 1)}';
    }
    return name;
  }

  static String join(String prefix, String name) {
    final String encoded = segment(name);
    return prefix == '/' ? '/$encoded' : '$prefix/$encoded';
  }
}
