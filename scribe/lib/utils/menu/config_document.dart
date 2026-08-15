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

import '../../core/console/console.dart';

class ConfigDocument implements MenuDocument {
  ConfigDocument([Map<String, dynamic>? values]) : values = values ?? <String, dynamic>{};

  factory ConfigDocument.from(dynamic raw) =>
      ConfigDocument(raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map));

  final Map<String, dynamic> values;

  @override
  String read(List<String> path) => _read(values, path);

  @override
  bool filled(List<String> path) => read(path).trim().isNotEmpty;

  @override
  void write(List<String> path, String value) => _write(values, path, value);

  @override
  dynamic node(List<String> path) => _node(values, path);

  @override
  void remove(List<String> path) => _remove(values, path);

  String get name => read(const <String>['name']);

  String get machineId => read(const <String>['machine']);
}

String _read(Map<String, dynamic> doc, List<String> path) => (_node(doc, path) ?? '').toString();

dynamic _node(Map<String, dynamic> doc, List<String> path) {
  dynamic node = doc;
  for (final String key in path) {
    if (node is! Map) return null;
    node = node[key];
  }
  return node;
}

void _write(Map<String, dynamic> doc, List<String> path, String value) {
  Map<String, dynamic> node = doc;
  for (final String key in path.sublist(0, path.length - 1)) {
    final dynamic child = node[key];
    if (child is! Map) {
      node[key] = <String, dynamic>{};
    } else if (child is! Map<String, dynamic>) {
      node[key] = Map<String, dynamic>.from(child);
    }
    node = node[key] as Map<String, dynamic>;
  }
  node[path.last] = value;
}

void _remove(Map<String, dynamic> doc, List<String> path) {
  final dynamic parent = _node(doc, path.sublist(0, path.length - 1));
  if (parent is Map) parent.remove(path.last);
}
