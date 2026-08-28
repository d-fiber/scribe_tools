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

import 'package:file/file.dart';
import 'package:scribe_tools/src/base/common.dart';
import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// The file a module declares what it needs and what it exposes in.
const String configurationFileName = 'configuration.yaml';

/// The directory the recipes sit in, one subdirectory per resource type.
const String recipesDirectoryName = 'recipes';

/// One thing a module needs, said without saying where it comes from.
///
/// A resource is the seam the whole deployment engine turns on: the socle and
/// the packages declare what they need, and a recipe answers for it. What
/// answers is decided by the target and never by the module that asked.
class Resource {
  /// Holds one resource as the module that needs it declared it.
  const Resource({required this.name, required this.type, required this.declaredBy});

  /// The name the bindings and the placement refer to it by, unique in a stack.
  final String name;

  /// What kind of thing it is, which decides which recipes may answer for it.
  final String type;

  /// The module that declared it, named in a refusal so the file is findable.
  final String declaredBy;
}

/// A resource once a recipe has answered for it.
class ResolvedResource {
  /// Holds [resource] as [className] resolved it, with the [outputs] it gives.
  const ResolvedResource({
    required this.resource,
    required this.className,
    required this.outputs,
    this.containerServices = const <String>{},
  });

  /// The declaration this answers.
  final Resource resource;

  /// The recipe that answered, which is the class the target asked for.
  final String className;

  /// The compose services this resource brings when it is a container.
  ///
  /// It is read from the `container` recipe whatever answered, because it is the
  /// answer to a question the other recipes cannot be asked: which services stop
  /// being part of the stack when this resource is satisfied elsewhere.
  final Set<String> containerServices;

  /// What a consumer connects with: the host, the port, the credentials, the URL.
  ///
  /// The contract belongs to the type and not to the recipe, so `host` means the
  /// same thing whether a container or a managed service answered. That is what
  /// lets the binding be written once.
  final Map<String, String> outputs;
}

/// Every resource a stack needs, and what each of them resolved to.
class Resources {
  /// Holds [resolved] in the order the declarations were read.
  Resources(List<ResolvedResource> resolved) : resolved = List<ResolvedResource>.unmodifiable(resolved);

  /// Every resource of the stack, resolved.
  final List<ResolvedResource> resolved;

  /// The resources of the socle and of [mounted], the mounted packages by default.
  ///
  /// The socle's declaration is read from the tool rather than from the
  /// framework checkout, for the same reason its capacity is: it describes the
  /// compose templates the tool ships, and the two would otherwise be free to
  /// describe different services.
  ///
  /// A package's is read from the checkout, beside the code that needs it, and
  /// so is the recipe answering for a type the package owns: `bucket` belongs to
  /// `storage`, and nothing of the socle should have to know the word.
  /// Every resource of the socle and of [mounted], placed the way [placement]
  /// says.
  ///
  /// [placement] answers for one resource by name, and a target that says
  /// nothing about a resource leaves it in a container, which is the stack as it
  /// was before anything could be placed anywhere else.
  static Resources load({List<Package>? mounted, Placement Function(String resource)? placement}) {
    final Directory root = SocleOps().root;
    final List<Package> found = mounted ?? Packages.load().active;

    return read(
      <File>[
        root.childFile('$configurationFileName$kTemplateSuffix'),
        for (final Package package in found) package.directory.childFile(configurationFileName),
      ],
      recipes: <Directory>[
        root.childDirectory(recipesDirectoryName),
        for (final Package package in found)
          package.directory.childDirectory(fragmentDirectory).childDirectory(recipesDirectoryName),
      ],
      placement: placement ?? (String _) => Placement.inContainer,
    );
  }

  /// The resources [declarations] ask for, each answered from one of [recipes].
  ///
  /// A declaration that is not there declares nothing, which is what a package
  /// that needs no resource of its own looks like. A missing socle declaration
  /// is a different thing and is refused by [load], which names it.
  static Resources read(
    Iterable<File> declarations, {
    required List<Directory> recipes,
    Placement Function(String resource)? placement,
  }) => Resources(<ResolvedResource>[
    for (final File file in declarations)
      for (final Resource resource in _readFile(file))
        _resolve(resource, recipes, (placement ?? (String _) => Placement.inContainer)(resource.name)),
  ]);

  /// Every compose service that is not part of the stack any more.
  ///
  /// A resource placed anywhere but in a container brings no container, so the
  /// service that used to be it leaves the document along with every dependency
  /// on it.
  Set<String> get suppressedServices => <String>{
    for (final ResolvedResource resource in resolved)
      if (resource.className != containerPlacement) ...resource.containerServices,
  };

  /// The template values a binding reads, one per output of every resource.
  ///
  /// A key is `resource_<name>_<output>`, so `REDIS_URL={{resource_redis_url}}`
  /// in an audience file is filled by whatever answered for `redis`.
  Map<String, String> get values => <String, String>{
    for (final ResolvedResource resource in resolved)
      for (final MapEntry<String, String> output in resource.outputs.entries)
        'resource_${resource.resource.name}_${output.key}': output.value,
  };

  static ResolvedResource _resolve(Resource resource, List<Directory> recipes, Placement placement) {
    final String className = placement.recipeName;
    final File? recipe = _recipeIn(recipes, resource.type, className);
    if (recipe == null) {
      throwToolExit(
        'No $className recipe for a ${resource.type}, which ${resource.declaredBy} needs as "${resource.name}". '
        'Whoever owns the type carries it, so it goes under '
        '${resource.declaredBy}/$fragmentDirectory/$recipesDirectoryName/${resource.type}/$className.yaml',
      );
    }

    final Object? document = loadYaml(recipe.readAsStringSync());
    if (document is! YamlMap || document['outputs'] is! YamlMap) {
      throwToolExit('${recipe.path}: the file must hold a mapping under "outputs".');
    }

    return ResolvedResource(
      resource: resource,
      className: className,
      containerServices: _servicesOf(_recipeIn(recipes, resource.type, containerPlacement)),
      outputs: <String, String>{
        for (final MapEntry<Object?, Object?> output in (document['outputs'] as YamlMap).entries)
          '${output.key}': _output(output.value, output.key, recipe),
      },
    );
  }

  static String _output(Object? value, Object? key, File recipe) {
    if (value is String) return value;
    if (value is int || value is bool) return '$value';

    throwToolExit('${recipe.path}: output "$key" must be text, a number or a boolean.');
  }

  /// The services a container recipe says it brings, none when it says nothing.
  static Set<String> _servicesOf(File? recipe) {
    if (recipe == null) return const <String>{};

    final Object? document = loadYaml(recipe.readAsStringSync());
    if (document is! YamlMap || document['brings'] is! YamlList) return const <String>{};

    return <String>{for (final Object? name in document['brings'] as YamlList) '$name'};
  }

  /// The recipe answering for [type] as [className], from whoever owns the type.
  ///
  /// The socle is searched first and a package after it, so a project that owns
  /// a type nothing else does simply adds a directory and is found.
  static File? _recipeIn(List<Directory> recipes, String type, String className) {
    for (final Directory root in recipes) {
      for (final String name in <String>['$className.yaml$kTemplateSuffix', '$className.yaml']) {
        final File candidate = root.childDirectory(type).childFile(name);
        if (candidate.existsSync()) return candidate;
      }
    }

    return null;
  }

  /// What [file] requires, nothing when it is not there or declares no resource.
  ///
  /// Both halves of a declaration are optional: a module may expose settings and
  /// need no resource, or need one and expose nothing.
  static List<Resource> _readFile(File file) {
    if (!file.existsSync()) return const <Resource>[];

    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throwToolExit('${file.path}: the file must be a mapping.');
    }

    final Object? required = document['requires'];
    if (required == null) return const <Resource>[];
    if (required is! YamlList) {
      throwToolExit('${file.path}: "requires" must be a list of resources.');
    }

    return <Resource>[for (final Object? entry in required) _readResource(entry, file)];
  }

  static Resource _readResource(Object? entry, File file) {
    if (entry is! YamlMap) {
      throwToolExit('${file.path}: every required resource must be a mapping.');
    }

    return Resource(
      name: _string(entry, 'name', file),
      type: _string(entry, 'type', file),
      declaredBy: file.parent.basename,
    );
  }

  static String _string(YamlMap node, String key, File file) {
    final Object? value = node[key];
    if (value is! String) throwToolExit('${file.path}: "$key" is missing, or is not text.');

    return value;
  }
}
