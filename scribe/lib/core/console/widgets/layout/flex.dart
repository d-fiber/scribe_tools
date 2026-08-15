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

import '../../framework/framework.dart';

enum MainAxisAlignment { start, center, end, spaceBetween, spaceAround, spaceEvenly }

enum CrossAxisAlignment { start, center, end, stretch }

enum MainAxisSize { min, max }

enum FlexFit { tight, loose }

class Flexible extends RenderWidget {
  const Flexible({required this.child, this.flex = 1, this.fit = FlexFit.loose, super.key})
    : assert(flex > 0, 'Flexible flex must be greater than zero');

  final Widget child;
  final int flex;
  final FlexFit fit;

  @override
  List<Widget> get children => <Widget>[child];

  @override
  Frame paint(Constraints constraints, List<Frame> children) => children.single;
}

class Expanded extends Flexible {
  const Expanded({required super.child, super.flex, super.key}) : super(fit: FlexFit.tight);
}

class Spacer extends RenderWidget {
  const Spacer({this.flex = 1, super.key}) : assert(flex > 0, 'Spacer flex must be greater than zero');

  final int flex;

  @override
  Frame paint(Constraints constraints, List<Frame> children) => const Frame.empty();
}

int flexOf(Widget widget) => switch (widget) {
  Flexible(flex: final int flex) => flex,
  Spacer(flex: final int flex) => flex,
  _ => 0,
};

FlexFit fitOf(Widget widget) => switch (widget) {
  Flexible(fit: final FlexFit fit) => fit,
  _ => FlexFit.tight,
};

List<int> distribute(List<int> weights, int free) {
  final int total = weights.fold(0, (int sum, int weight) => sum + weight);
  if (total <= 0 || free <= 0) return List<int>.filled(weights.length, 0);

  final List<int> shares = <int>[];
  int accumulated = 0;
  int given = 0;
  for (final int weight in weights) {
    accumulated += weight;
    final int target = free * accumulated ~/ total;
    shares.add(target - given);
    given = target;
  }
  return shares;
}

List<int> spacingFor(MainAxisAlignment alignment, int free, int count) {
  if (count == 0) return const <int>[0];
  if (free <= 0) return List<int>.filled(count + 1, 0);

  final List<int> weights = switch (alignment) {
    MainAxisAlignment.start => <int>[for (int slot = 0; slot <= count; slot++) slot == count ? 1 : 0],
    MainAxisAlignment.end => <int>[for (int slot = 0; slot <= count; slot++) slot == 0 ? 1 : 0],
    MainAxisAlignment.center => <int>[for (int slot = 0; slot <= count; slot++) slot == 0 || slot == count ? 1 : 0],
    MainAxisAlignment.spaceBetween when count < 2 => <int>[
      for (int slot = 0; slot <= count; slot++) slot == count ? 1 : 0,
    ],
    MainAxisAlignment.spaceBetween => <int>[
      for (int slot = 0; slot <= count; slot++) slot == 0 || slot == count ? 0 : 1,
    ],
    MainAxisAlignment.spaceAround => <int>[
      for (int slot = 0; slot <= count; slot++) slot == 0 || slot == count ? 1 : 2,
    ],
    MainAxisAlignment.spaceEvenly => List<int>.filled(count + 1, 1),
  };

  return distribute(weights, free);
}
