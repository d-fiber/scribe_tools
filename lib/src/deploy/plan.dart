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

import 'package:scribe_tools/src/deploy/configuration.dart';
import 'package:scribe_tools/src/deploy/resources.dart';
import 'package:scribe_tools/src/scribe_manifest.dart';

/// What a deployment of one target comes to, before anything is done about it.
///
/// A plan is what `deploy --plan` prints and what `deploy` acts on, and the two
/// are the same object on purpose: what is shown has to be what happens.
class DeploymentPlan {
  /// Holds the plan of [target], with [resources] already placed.
  const DeploymentPlan({required this.target, required this.resources, required this.services});

  /// The target this deploys onto.
  final Target target;

  /// Every resource of the stack, each answered by the recipe its target names.
  final Resources resources;

  /// The compose services that are still part of the stack.
  final List<String> services;

  /// The resources that stay containers of the stack.
  Iterable<ResolvedResource> get inContainers =>
      resources.resolved.where((ResolvedResource r) => r.className == containerPlacement);

  /// The resources that exist already, whose outputs are read rather than made.
  Iterable<ResolvedResource> get alreadyThere =>
      resources.resolved.where((ResolvedResource r) => r.className == externalPlacement);

  /// The resources a recipe has to create, which is what costs money.
  ///
  /// It is the only part of a plan that is not reversible by stopping the stack,
  /// and it is why `deploy` asks before the first one and never asks again.
  Iterable<ResolvedResource> get provisioned => resources.resolved.where(
    (ResolvedResource r) => r.className != containerPlacement && r.className != externalPlacement,
  );

  /// Whether anything has to be created before the stack can start.
  bool get createsAnything => provisioned.isNotEmpty;

  /// What stops this plan from being applied, empty when nothing does.
  ///
  /// A blocker is not a mistake in the project: it is a capability the engine
  /// does not have yet, named where it is met rather than discovered halfway
  /// through a deployment.
  List<String> get blockers => <String>[
    if (target.kind == TargetKind.vps || target.kind == TargetKind.hybrid)
      if (target.host.isEmpty)
        'targets.${target.name}.host names nobody, and a ${target.kind.name} target is reached over SSH.'
      else if (target.registry.isEmpty)
        _needsARegistry(target),
  ];

  /// Why a target reached over SSH cannot be deployed to without a registry.
  static String _needsARegistry(Target target) =>
      'targets.${target.name}.registry names nothing, and a host that is not this one pulls its images '
      'rather than building them from paths of this machine.';

  /// Whether the stack of this plan can be started where the command runs.
  bool get runsHere => target.kind == TargetKind.dev || target.kind == TargetKind.machine;
}
