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

import 'package:scribe/src/globals.dart' as globals;
import 'package:scribe/src/project_templates.dart';
import 'package:scribe/src/sdk_target.dart';

class ProjectScaffold {
  ProjectScaffold({
    required this.root,
    required this.name,
    required this.target,
    required this.templates,
  });

  final Directory root;
  final String name;
  final SdkTarget target;
  final ProjectTemplates templates;

  static const List<String> _generated = <String>['docs', 'ops', 'sdk'];

  List<TemplateFile> get _files => templates.filesFor(target.name);

  String get generatedDirectory => '.$name';

  String get hostName => name.replaceAll('_', '-');

  List<String> get files => <String>[for (final TemplateFile file in _files) file.destination];

  Future<void> write() async {
    final Map<String, String> values = <String, String>{
      'name': name,
      'sdk': target.name,
      'host': hostName,
    };

    for (final String directory in _generated) {
      await _directory(p.join(root.path, generatedDirectory, directory));
    }

    for (final TemplateFile file in _files) {
      await _write(file.destination, file.isEmptyKeeper ? '' : templates.render(file, values));
    }
  }

  Future<void> _directory(String path) => globals.fs.directory(path).create(recursive: true);

  Future<void> _write(String relative, String content) async {
    final File file = globals.fs.file(p.join(root.path, p.joinAll(p.posix.split(relative))));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}
