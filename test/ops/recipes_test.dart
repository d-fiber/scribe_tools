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

import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'capacity_source.dart';

const FileSystem _fs = LocalFileSystem();

/// A type that can be placed, and the recipes that answer for it.
///
/// The contract and its recipes sit in the same directory, so the two cannot
/// come to describe different types.
class RecipeFamily {
  const RecipeFamily({required this.type, required this.contract, required this.recipes});

  /// The type these recipes answer for, which is the name of their directory.
  final String type;

  /// The `contract.yaml` that says what a consumer of this type may read, when one was written.
  final File? contract;

  /// Every recipe of the family, in a fixed order, its contract excluded.
  final List<File> recipes;
}

/// Every recipe the framework carries, wherever it lives.
///
/// Two roots, because a type comes either from the socle or from the package
/// that introduced it, and a project resolves both the same way.
List<RecipeFamily> get families => <RecipeFamily>[
  ..._familiesUnder(_fs.directory('templates/deploy/recipes')),
  for (final Directory package in packagesRoot.listSync().whereType<Directory>())
    ..._familiesUnder(package.childDirectory('deploy').childDirectory('recipes')),
];

List<RecipeFamily> _familiesUnder(Directory root) {
  if (!root.existsSync()) return const <RecipeFamily>[];

  final List<Directory> types = root.listSync().whereType<Directory>().toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));

  return <RecipeFamily>[
    for (final Directory type in types)
      RecipeFamily(
        type: p.basename(type.path),
        contract: _theContractIn(type),
        recipes: type.listSync().whereType<File>().where((File file) => !_describesRecipes(file)).toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)),
      ),
  ];
}

File? _theContractIn(Directory type) {
  for (final String name in <String>['contract.yaml', 'contract.yaml.tmpl']) {
    final File candidate = type.childFile(name);
    if (candidate.existsSync()) return candidate;
  }

  return null;
}

/// Whether this file describes the recipes beside it rather than being one.
///
/// A contract says what the type promises, a `params.json` says what a
/// project would write for one recipe, and a `capabilities.yaml` says what a
/// recipe already has set up: none of the three answers for the type itself.
bool _describesRecipes(File file) =>
    plainly(file).startsWith('contract.yaml') ||
    plainly(file).endsWith('.params.json') ||
    plainly(file).endsWith('.capabilities.yaml');

/// The name of [file] as the socle wrote it, without the suffix the copy adds.
///
/// The templates carry every recipe under `.tmpl`, which is what keeps `deno
/// fmt` from rewriting the placeholders inside them. The name below it is the
/// one that says what the file is.
String plainly(File file) {
  final String name = p.basename(file.path);

  return name.endsWith('.tmpl') ? name.substring(0, name.length - '.tmpl'.length) : name;
}

/// A recipe with an answer in the place of each of its placeholders.
///
/// Three passes, because the place decides the form. A placeholder that is a
/// whole string, or that stands where a JSON value starts, receives a literal,
/// so a list arrives as a list. One written inside a longer string receives its
/// bare scalar, since `"postgres:{{version}}"` wants the version and not a
/// second pair of quotes.
String fill(String recipe, Map<String, Object?> params) {
  String answer(String name) => jsonEncode(params[name] ?? name);

  return recipe
      .replaceAllMapped(RegExp(r'"\{\{([a-z_]+)\}\}"'), (Match match) => answer(match.group(1)!))
      .replaceAllMapped(
        RegExp(r'(": |\[|, )\{\{([a-z_]+)\}\}'),
        (Match match) => '${match.group(1)}${answer(match.group(2)!)}',
      )
      .replaceAllMapped(RegExp(r'\{\{([a-z_]+)\}\}'), (Match match) => '${params[match.group(1)] ?? match.group(1)}');
}

/// The values a project would write under `params:` for [recipe].
///
/// The file is optional: a recipe whose placeholders are all plain strings
/// needs no example, and each one then answers with its own name.
Map<String, Object?> paramsOf(File recipe) {
  final String stem = plainly(recipe).split('.').first;
  for (final String name in <String>['$stem.params.json', '$stem.params.json.tmpl']) {
    final File given = recipe.parent.childFile(name);
    if (given.existsSync()) return json.decode(given.readAsStringSync()) as Map<String, Object?>;
  }

  return const <String, Object?>{};
}

/// What a recipe returns, read whichever of the two forms it is written in.
///
/// A recipe carries placeholders, so neither parser reads it as it sits, and
/// [fill] answers each one first.
Set<String> outputsOf(File recipe) {
  final bool machine = plainly(recipe).endsWith('.tf.json');
  final String filled = fill(recipe.readAsStringSync(), paramsOf(recipe));

  if (machine) {
    final Map<String, Object?> document = json.decode(filled) as Map<String, Object?>;

    return (document['output']! as Map<String, Object?>).keys.toSet();
  }

  final YamlMap document = loadYaml(filled) as YamlMap;

  return (document['outputs']! as YamlMap).keys.cast<String>().toSet();
}

void main() {
  test('the framework carries a recipe for every type it lets a project place', () {
    expect(families, isNotEmpty, reason: 'no contract was found, so nothing below tested anything');
  });

  for (final RecipeFamily family in families) {
    test('every ${family.type} recipe returns what the type promises', () {
      final File? written = family.contract;
      expect(
        written,
        isNotNull,
        reason:
            'the ${family.type} recipes say nothing about what they return, '
            'so a consumer has no promise to be written against',
      );

      final YamlMap contract = loadYaml(written!.readAsStringSync()) as YamlMap;
      final Set<String> promised = (contract['outputs']! as YamlList).cast<String>().toSet();

      expect(family.recipes, isNotEmpty, reason: '${written.path} promises what nothing answers');

      for (final File recipe in family.recipes) {
        expect(
          outputsOf(recipe),
          containsAll(promised),
          reason:
              '${recipe.path} does not return everything the ${family.type} type promises, '
              'and a consumer is written against the promise rather than against the recipe',
        );
      }
    });
  }
}
