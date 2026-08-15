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

import 'package:scribe/core/file_system_entity/entity.dart';
import 'package:scribe/core/file_system_entity/source.dart';

abstract class Node extends Entity {
  final Directory _directory;

  Node(super.path) : _directory = Directory(path);

  Directory get directory => _directory;

  @override
  Future<bool> isExists() => _directory.exists();

  @override
  Future<void> delete() => _directory.delete(recursive: true);

  @override
  Future<void> create() async {
    if (!await isExists()) {
      await _directory.create(recursive: true);
    }
  }

  Future<List<Source>> list() async {
    if (!await isExists()) return <Source>[];
    final List<Source> sources = <Source>[];
    await for (final FileSystemEntity entity in _directory.list(recursive: true, followLinks: false)) {
      if (entity is File) sources.add(Source(entity.path));
    }
    return sources;
  }
}
