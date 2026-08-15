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
import '../widgets/text/text.dart';
import 'menu_document.dart';

typedef SuffixBuilder = Widget Function(String value);
typedef FieldValidator = String? Function(String value);
typedef EntryBuilder = List<MenuEntry> Function(MenuDocument document);

class PlaceholderText extends StatelessWidget {
  const PlaceholderText(this.value, this.empty, {super.key});

  final String value;
  final String empty;

  @override
  Widget build(BuildContext context) =>
      value.isEmpty ? Text(empty, color: ConsoleTheme.of(context).colors.feedback.error) : Text(value);
}

Widget requiredValue(String value) => PlaceholderText(value, 'Required*');

Widget optionalValue(String value) => PlaceholderText(value, 'Not configured');

SuffixBuilder placeholder(String empty) =>
    (String value) => PlaceholderText(value, empty);

SuffixBuilder constantSuffix(String text) =>
    (String value) => Text(text);

abstract interface class MenuActions {
  MenuDocument get document;

  Future<String?> promptName(String label);

  Future<bool> confirm(String prompt);

  Future<void> notify();
}

class MenuChoices {
  const MenuChoices({required this.prompt, required this.ids, required this.labels});

  final String prompt;
  final List<String> ids;
  final List<String> labels;
}

sealed class MenuEntry {
  const MenuEntry(this.label);

  final String label;
}

class MenuValue extends MenuEntry {
  MenuValue(super.label, this.path, {this.suffix = optionalValue, this.validate, this.choices});

  final List<String> path;
  final SuffixBuilder suffix;
  final FieldValidator? validate;
  final MenuChoices? choices;

  MenuValue copyWith({SuffixBuilder? suffix, FieldValidator? validate}) =>
      MenuValue(label, path, suffix: suffix ?? this.suffix, validate: validate ?? this.validate, choices: choices);
}

class MenuGroup extends MenuEntry {
  const MenuGroup(super.label, this.children, {this.key, this.onAdd, this.onRemove});

  final EntryBuilder children;
  final Object? key;
  final Future<String?> Function(MenuActions actions)? onAdd;
  final Future<String?> Function(MenuActions actions, Object? key)? onRemove;
}
