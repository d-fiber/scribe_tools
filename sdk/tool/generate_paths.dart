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

import 'dart:io';

import 'package:sdk/core/paths/infra_files.dart';
import 'package:path/path.dart' as p;

// kernel-cli ne doit jamais connaître de chemin sous lib/ (kernel ne
// dépend jamais de project, voir CLAUDE.md) — exclu du scan en plus des
// exclusions déjà présentes côté cli.
const Set<String> excludedNames = {
  'node_modules',
  'build',
  '__pycache__',
  'scripts',
  'lib',
};

const Set<String> allowedDotfiles = {'.env', '.tmp_x25519.pem'};

bool includeFile(String name) {
  if (name.endsWith('.md')) return false;
  if (name.startsWith('.') && !allowedDotfiles.contains(name)) return false;
  return true;
}

const List<String> forcedDirectories = ['scribe/opensearch'];

const List<String> forcedFiles = ['.tmp_x25519.pem'];

const Set<String> reservedIdentifiers = {
  'class',
  'void',
  'in',
  'is',
  'new',
  'this',
  'super',
  'if',
  'else',
  'for',
  'while',
  'do',
  'switch',
  'case',
  'default',
  'break',
  'continue',
  'return',
  'try',
  'catch',
  'finally',
  'throw',
  'const',
  'final',
  'var',
  'static',
  'import',
  'export',
  'library',
  'part',
  'extends',
  'implements',
  'with',
  'enum',
  'typedef',
  'get',
  'set',
  'operator',
  'true',
  'false',
  'null',
};

class TreeNode {
  TreeNode(this.name, this.relativePath);

  final String name;
  final String relativePath;
  final List<TreeNode> directories = [];
  final List<String> files = [];
}

TreeNode scan(Directory directory, String relativePath) {
  final TreeNode node = TreeNode(p.basename(directory.path), relativePath);
  final List<FileSystemEntity> entries = directory.listSync(followLinks: false)
    ..sort(
      (FileSystemEntity a, FileSystemEntity b) =>
          p.basename(a.path).compareTo(p.basename(b.path)),
    );

  for (final FileSystemEntity entity in entries) {
    final String name = p.basename(entity.path);
    if (excludedNames.contains(name)) continue;
    if (entity is Directory) {
      if (name.startsWith('.')) continue;
      node.directories.add(scan(entity, p.join(relativePath, name)));
    } else if (entity is File) {
      if (includeFile(name)) node.files.add(name);
    }
  }
  return node;
}

void mergeForcedPath(
  TreeNode root,
  String relativePath, {
  required bool isDirectory,
}) {
  final List<String> segments = p.split(relativePath);
  TreeNode current = root;
  for (int i = 0; i < segments.length - 1; i++) {
    final String segment = segments[i];
    TreeNode? child = current.directories.firstWhere(
      (TreeNode d) => d.name == segment,
      orElse: () => TreeNode('', ''),
    );
    if (child.name.isEmpty) {
      child = TreeNode(segment, p.joinAll(segments.sublist(0, i + 1)));
      current.directories.add(child);
    }
    current = child;
  }

  final String leaf = segments.last;
  if (isDirectory) {
    final bool exists = current.directories.any((TreeNode d) => d.name == leaf);
    if (!exists) current.directories.add(TreeNode(leaf, relativePath));
  } else {
    if (!current.files.contains(leaf)) current.files.add(leaf);
  }
}

List<String> parseGitignoreForcedPaths(File gitignore) {
  if (!gitignore.existsSync()) return [];
  return gitignore
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where(
        (String line) =>
            line.isNotEmpty && !line.startsWith('#') && !line.contains('*'),
      )
      .toList();
}

String pascalCase(String input) {
  final List<String> tokens = input
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((String t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return 'Unnamed';
  return tokens
      .map((String t) => t[0].toUpperCase() + t.substring(1).toLowerCase())
      .join();
}

String camelCase(String input) {
  final String pascal = pascalCase(input);
  final String camel = pascal[0].toLowerCase() + pascal.substring(1);
  return RegExp(r'^[0-9]').hasMatch(camel) ? 'f$camel' : camel;
}

String classNameFor(String relativePath) {
  if (relativePath.isEmpty) return 'InfrastructureRoot';
  final String joined = p.split(relativePath).map(pascalCase).join();
  return RegExp(r'^[0-9]').hasMatch(joined) ? 'T$joined' : joined;
}

class MemberNames {
  final Set<String> _used = {};

  String unique(String base) {
    String candidate = base;
    int suffix = 2;
    while (_used.contains(candidate) ||
        reservedIdentifiers.contains(candidate)) {
      candidate = '$base$suffix';
      suffix++;
    }
    _used.add(candidate);
    return candidate;
  }
}

void writeClass(StringBuffer buffer, TreeNode node, {required bool isRoot}) {
  final String className = classNameFor(node.relativePath);
  final MemberNames members = MemberNames();

  buffer.writeln('class $className {');
  if (isRoot) {
    buffer.writeln('  $className(Directory root) : _self = root;');
  } else {
    buffer.writeln(
      "  $className(Directory parent) : _self = Directory(p.join(parent.path, '${node.name}'));",
    );
  }
  buffer.writeln();
  buffer.writeln('  final Directory _self;');
  buffer.writeln();
  buffer.writeln('  Directory get directory => _self;');

  for (final String file in node.files) {
    final String member = members.unique(camelCase(file));
    buffer.writeln();
    buffer.writeln("  File get $member => File(p.join(_self.path, '$file'));");
  }

  for (final TreeNode child in node.directories) {
    final String member = members.unique(camelCase(child.name));
    final String childClassName = classNameFor(child.relativePath);
    buffer.writeln();
    buffer.writeln('  $childClassName get $member => $childClassName(_self);');
  }

  buffer.writeln('}');
  buffer.writeln();

  for (final TreeNode child in node.directories) {
    writeClass(buffer, child, isRoot: false);
  }
}

Future<void> main() async {
  final Directory root = InfraFiles.root;
  final TreeNode tree = scan(root, '');

  for (final String relativePath in forcedDirectories) {
    mergeForcedPath(tree, relativePath, isDirectory: true);
  }
  for (final String relativePath in parseGitignoreForcedPaths(
    File(p.join(root.path, '.gitignore')),
  )) {
    final bool isDirectory = relativePath.endsWith('/');
    mergeForcedPath(
      tree,
      isDirectory
          ? relativePath.substring(0, relativePath.length - 1)
          : relativePath,
      isDirectory: isDirectory,
    );
  }
  for (final String relativePath in forcedFiles) {
    mergeForcedPath(tree, relativePath, isDirectory: false);
  }

  final StringBuffer buffer = StringBuffer();
  buffer.writeln('''
// Copyright (C) ${DateTime.now().year} Fiber
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
//
// This file is auto-generated, do not edit manually.

import 'dart:io';

import 'package:path/path.dart' as p;
''');

  writeClass(buffer, tree, isRoot: true);

  final File output = File(
    p.join(Directory.current.path, 'lib/core/paths/tree.g.dart'),
  );
  await output.writeAsString(buffer.toString());
  stderr.writeln('Generated ${output.path}');
}
