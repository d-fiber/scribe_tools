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
import 'package:scribe_tools/src/ops/configuration.dart';
import 'package:scribe_tools/src/ops/socle.dart';
import 'package:scribe_tools/src/packages.dart';
import 'package:scribe_tools/src/project.dart';
import 'package:scribe_tools/src/templates.dart';
import 'package:yaml/yaml.dart';

/// The file a module declares what it needs and what it exposes in.
const String configurationFileName = 'configuration.yaml';

/// The directory the recipes sit in, one subdirectory per resource type.
const String recipesDirectoryName = 'recipes';

/// The file a type says what every recipe for it has to return in.
///
/// It sits beside the recipes and not inside one, because the contract belongs
/// to the type: `host` means the same thing whether a container or a managed
/// service answered, and that is what lets the binding be written once.
const String contractFileName = 'contract.yaml';

/// One thing a module needs, said without saying where it comes from.
///
/// A resource is the seam the whole deployment engine turns on: the socle and
/// the packages declare what they need, and a recipe answers for it. What
/// answers is decided by the target and never by the module that asked.
class Resource {
  /// Holds one resource as the module that needs it declared it.
  const Resource({
    required this.name,
    required this.type,
    required this.declaredBy,
    this.capabilities = const <String>[],
  });

  /// The name the bindings and the placement refer to it by, unique in a stack.
  final String name;

  /// What kind of thing it is, which decides which recipes may answer for it.
  final String type;

  /// The module that declared it, named in a refusal so the file is findable.
  final String declaredBy;

  /// What the module needs a resource of this type to already know how to do.
  ///
  /// An extension it needs loaded, a right its role needs to hold: things a
  /// placement can satisfy or not regardless of whether it answers with the
  /// right host and port. Empty by default, which asks nothing beyond what
  /// the type's contract already promises.
  final List<String> capabilities;
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
  static Resources load({
    Project? project,
    List<Package>? mounted,
    Placement Function(String resource)? placement,
    Map<String, Map<String, String>> outputs = const <String, Map<String, String>>{},
  }) {
    final List<Package> found = mounted ?? Packages.load().active;

    _refuseADuplicateRecipeType(found);

    final Directory root = SocleOps().root;

    return read(
      <(File, String)>[
        (root.childFile('$configurationFileName$kTemplateSuffix'), 'the socle'),
        for (final Package package in found)
          (package.directory.childDirectory(deployDirectory).childFile(configurationFileName), package.name),
      ],
      recipes: recipeRoots(project: project, mounted: found),
      placement: placement ?? (String _) => Placement.inContainer,
      outputs: outputs,
    );
  }

  /// What [file] asks for, before anything answers, none when it asks nothing.
  static List<Resource> declaredIn(File file) => _readFile(file, declaredBy: file.parent.basename);

  /// Every resource the socle and [mounted] declare, before anything answers.
  ///
  /// A deployment needs this list before it renders, because a resource a recipe
  /// has to create has no outputs until the apply has run, and the render is
  /// what those outputs are for.
  static List<Resource> declared({List<Package>? mounted}) {
    final List<Package> found = mounted ?? Packages.load().active;

    return <Resource>[
      ..._readFile(SocleOps().root.childFile('$configurationFileName$kTemplateSuffix'), declaredBy: 'the socle'),
      for (final Package package in found)
        ..._readFile(
          package.directory.childDirectory(deployDirectory).childFile(configurationFileName),
          declaredBy: package.name,
        ),
    ];
  }

  /// The file a recipe of [className] for [type] is written in, null when none.
  ///
  /// Two shapes exist: a `.yaml` holding the outputs, and a `.tf.json` holding
  /// configuration a provider applies to produce them. [roots] is searched in
  /// order, and the first match wins: a project's own recipe therefore always
  /// beats one the socle or a package would have answered with instead.
  static File? recipeFor(List<Directory> roots, String type, String className) => _recipeIn(roots, type, className);

  /// Where a recipe for the socle, [mounted] and [project] is looked for, in
  /// the order a match is taken.
  ///
  /// [project]'s own `deploy/recipes/` comes first, so a project that needs a
  /// fournisseur nobody has written does not wait for a release of the
  /// framework: it writes its own recipe and deploys the same day. The socle
  /// comes next, then each package, in the order [mounted] lists them.
  static List<Directory> recipeRoots({Project? project, List<Package>? mounted}) {
    final List<Package> found = mounted ?? Packages.load().active;

    return <Directory>[
      if (project != null) project.directory.childDirectory(deployDirectory).childDirectory(recipesDirectoryName),
      SocleOps().root.childDirectory(recipesDirectoryName),
      for (final Package package in found)
        package.directory.childDirectory(deployDirectory).childDirectory(recipesDirectoryName),
    ];
  }

  /// Refuses two packages of [found] that both own recipes for the same type.
  ///
  /// A type belongs to whoever writes its recipes, and `recipeRoots` picks the
  /// first match without saying which package that was. Two packages carrying
  /// `bucket` would make the answer depend on mount order, silently, so this
  /// closes the catalogue before it is searched.
  static void _refuseADuplicateRecipeType(List<Package> found) {
    final Map<String, List<String>> ownersByType = <String, List<String>>{};

    for (final Package package in found) {
      final Directory recipes = package.directory.childDirectory(deployDirectory).childDirectory(recipesDirectoryName);
      if (!recipes.existsSync()) continue;

      for (final FileSystemEntity entity in recipes.listSync()) {
        if (entity is! Directory) continue;
        ownersByType.putIfAbsent(entity.basename, () => <String>[]).add(package.name);
      }
    }

    for (final MapEntry<String, List<String>> entry in ownersByType.entries) {
      if (entry.value.length < 2) continue;

      throwToolExit(
        'Both ${entry.value.join(' and ')} carry recipes for a ${entry.key}, and only one package may '
        'own a type: recipeRoots would pick between them by mount order instead of by design.',
      );
    }
  }

  /// The resources [declarations] ask for, each answered from one of [recipes].
  ///
  /// A declaration that is not there declares nothing, which is what a package
  /// that needs no resource of its own looks like. A missing socle declaration
  /// is a different thing and is refused by [load], which names it.
  static Resources read(
    Iterable<(File file, String declaredBy)> declarations, {
    required List<Directory> recipes,
    Placement Function(String resource)? placement,
    Map<String, Map<String, String>> outputs = const <String, Map<String, String>>{},
  }) => Resources(<ResolvedResource>[
    for (final (File file, String declaredBy) in declarations)
      for (final Resource resource in _readFile(file, declaredBy: declaredBy))
        _resolve(
          resource,
          recipes,
          (placement ?? (String _) => Placement.inContainer)(resource.name),
          outputs: outputs,
        ),
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

  static ResolvedResource _resolve(
    Resource resource,
    List<Directory> recipes,
    Placement placement, {
    Map<String, Map<String, String>> outputs = const <String, Map<String, String>>{},
  }) {
    final String className = placement.recipeName;

    final File? recipe = _recipeIn(recipes, resource.type, className);
    if (recipe == null) {
      throwToolExit(
        'No $className recipe for a ${resource.type}, which ${resource.declaredBy} needs as "${resource.name}". '
        'Whoever owns the type carries it, so it goes under '
        '${resource.declaredBy}/$deployDirectory/$recipesDirectoryName/${resource.type}/$className.yaml',
      );
    }

    _refuseAnUnpromisedCapability(resource, className, recipe);

    // A resource somebody already provisioned answers with what it produced, and
    // no file on disk can hold that: it did not exist before the apply.
    if (outputs[resource.name] case final Map<String, String> made) {
      return ResolvedResource(
        resource: resource,
        className: className,
        containerServices: _servicesOf(_recipeIn(recipes, resource.type, containerPlacement)),
        outputs: made,
      );
    }

    final Object? document = loadYaml(recipe.readAsStringSync());
    if (document is! YamlMap || document['outputs'] is! YamlMap) {
      throwToolExit('${recipe.path}: the file must hold a mapping under "outputs".');
    }

    final Map<String, String> answered = <String, String>{
      for (final MapEntry<Object?, Object?> output in (document['outputs'] as YamlMap).entries)
        '${output.key}': _output(output.value, output.key, recipe),
    };

    _refuseAnIncompleteRecipe(recipes, resource, className, recipe, answered);

    return ResolvedResource(
      resource: resource,
      className: className,
      containerServices: _servicesOf(_recipeIn(recipes, resource.type, containerPlacement)),
      outputs: answered,
    );
  }

  static String _output(Object? value, Object? key, File recipe) {
    if (value is String) return value;
    if (value is int || value is bool) return '$value';

    throwToolExit('${recipe.path}: output "$key" must be text, a number or a boolean.');
  }

  /// Refuses a recipe that does not return everything its type promises.
  ///
  /// A field a recipe forgets is not an error anybody sees: it renders as an
  /// empty placeholder, and the service it was meant for fails on a host that is
  /// the empty string, three layers from the cause. The contract turns that into
  /// a refusal at the render, naming the field.
  static void _refuseAnIncompleteRecipe(
    List<Directory> recipes,
    Resource resource,
    String className,
    File recipe,
    Map<String, String> answered,
  ) {
    final Set<String> promised = _contractOf(recipes, resource.type);
    final List<String> missing = <String>[
      for (final String field in promised)
        if (!answered.containsKey(field)) field,
    ];
    if (missing.isEmpty) return;

    throwToolExit(
      'The $className recipe of a ${resource.type} returns no ${missing.join(', no ')}.\n'
      'A ${resource.type} promises ${promised.join(', ')}, whoever answers for it, '
      'because that is what its consumers are written against.\n'
      'The recipe is ${recipe.path}',
    );
  }

  /// Refuses a placement whose recipe does not promise a capability [resource] needs.
  ///
  /// This runs before a single output is read, let alone applied: the cost of a
  /// managed resource that cannot do what its consumer needs is a provisioned
  /// instance nobody can use, and placement is the last step that is free.
  ///
  /// `external` is exempt. What it names already exists, and the only thing the
  /// framework knows about it is what a project's `.env` says its address is;
  /// there is nothing on disk that could honestly answer for what it can do.
  /// Placing a resource there is the project vouching for it, not scribe.
  static void _refuseAnUnpromisedCapability(Resource resource, String className, File recipe) {
    if (resource.capabilities.isEmpty || className == externalPlacement) return;

    final Set<String> provided = _providesOf(recipe, className);
    final List<String> missing = <String>[
      for (final String capability in resource.capabilities)
        if (!provided.contains(capability)) capability,
    ];
    if (missing.isEmpty) return;

    throwToolExit(
      'The $className recipe of a ${resource.type} does not promise ${missing.join(', ')}, which '
      '${resource.declaredBy} needs "${resource.name}" to have.\n'
      'The recipe is ${recipe.path}; what it promises is declared beside it, in '
      '$className.capabilities.yaml',
    );
  }

  /// What [recipe] promises to already have set up, empty when it promises nothing.
  ///
  /// Read from `<class>.capabilities.yaml` beside the recipe and never from
  /// inside it: a `.tf.json` recipe is read by a provider that refuses a key it
  /// does not recognise, so what a recipe provides cannot live inside one, and a
  /// `.yaml` recipe keeps the same sidecar for the one rule to hold for both.
  static Set<String> _providesOf(File recipe, String className) {
    for (final String suffix in <String>[kTemplateSuffix, '']) {
      final File candidate = recipe.parent.childFile('$className.capabilities.yaml$suffix');
      if (!candidate.existsSync()) continue;

      final Object? document = loadYaml(candidate.readAsStringSync());
      if (document is! YamlMap || document['provides'] is! YamlList) {
        throwToolExit('${candidate.path}: the file must hold a list under "provides".');
      }

      return <String>{for (final Object? capability in document['provides'] as YamlList) '$capability'};
    }

    return const <String>{};
  }

  /// What a type promises, empty when it promises nothing yet.
  static Set<String> _contractOf(List<Directory> recipes, String type) {
    for (final Directory root in recipes) {
      for (final String name in <String>['$contractFileName$kTemplateSuffix', contractFileName]) {
        final File candidate = root.childDirectory(type).childFile(name);
        if (!candidate.existsSync()) continue;

        final Object? document = loadYaml(candidate.readAsStringSync());
        if (document is! YamlMap || document['outputs'] is! YamlList) {
          throwToolExit('${candidate.path}: the file must hold a list under "outputs".');
        }

        return <String>{for (final Object? field in document['outputs'] as YamlList) '$field'};
      }
    }

    return const <String>{};
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
      for (final String name in <String>[
        '$className.yaml$kTemplateSuffix',
        '$className.yaml',
        '$className.tf.json$kTemplateSuffix',
        '$className.tf.json',
      ]) {
        final File candidate = root.childDirectory(type).childFile(name);
        if (candidate.existsSync()) return candidate;
      }
    }

    return null;
  }

  /// What [file] requires, nothing when it is not there or declares no resource.
  ///
  /// Both halves of a declaration are optional: a module may expose settings and
  /// need no resource, or need one and expose nothing. [declaredBy] names the
  /// module for a refusal: every declaration file sits at the same
  /// `deploy/configuration.yaml`, so the name has to come from whoever is
  /// reading it, never from the path, which always ends in `deploy`.
  static List<Resource> _readFile(File file, {required String declaredBy}) {
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

    return <Resource>[for (final Object? entry in required) _readResource(entry, file, declaredBy)];
  }

  static Resource _readResource(Object? entry, File file, String declaredBy) {
    if (entry is! YamlMap) {
      throwToolExit('${file.path}: every required resource must be a mapping.');
    }

    return Resource(
      name: _string(entry, 'name', file),
      type: _string(entry, 'type', file),
      declaredBy: declaredBy,
      capabilities: _capabilitiesOf(entry, file),
    );
  }

  /// The `capabilities:` a required resource asks for, empty when it names none.
  static List<String> _capabilitiesOf(YamlMap entry, File file) {
    final Object? listed = entry['capabilities'];
    if (listed == null) return const <String>[];
    if (listed is! YamlList) {
      throwToolExit('${file.path}: "capabilities" must be a list of names.');
    }

    return <String>[for (final Object? name in listed) '$name'];
  }

  static String _string(YamlMap node, String key, File file) {
    final Object? value = node[key];
    if (value is! String) throwToolExit('${file.path}: "$key" is missing, or is not text.');

    return value;
  }
}
