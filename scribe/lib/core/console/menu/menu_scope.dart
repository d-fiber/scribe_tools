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

import '../framework/framework.dart';
import 'menu_document.dart';

class MenuController {
  MenuController({required this.document, required this.editable, this.onChanged, this.completionError});

  final MenuDocument document;
  final bool editable;
  final Future<void> Function()? onChanged;
  final String? Function()? completionError;

  Future<void> notify() async {
    final Future<void> Function()? changed = onChanged;
    if (changed != null) await changed();
  }
}

class MenuScope extends StatelessWidget {
  const MenuScope({required this.controller, required this.child, super.key});

  final MenuController controller;
  final Widget child;

  static MenuController of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<MenuScope>()?.controller ??
      (throw StateError('MenuScope.of() found no MenuScope above this widget. Push menu screens from runMenu().'));

  @override
  Widget build(BuildContext context) => child;
}
