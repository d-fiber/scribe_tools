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

part of '../framework.dart';

class ListStyle {
  const ListStyle({
    this.activePrefix = '❯',
    this.inactivePrefix = ' ',
    this.selected = '◉',
    this.unselected = '○',
    this.checked = '◼',
    this.unchecked = '◻',
    this.chevron = '>',
    this.height = 8,
  }) : assert(height > 0, 'ListStyle height must be greater than zero');

  final String activePrefix;
  final String inactivePrefix;
  final String selected;
  final String unselected;
  final String checked;
  final String unchecked;
  final String chevron;
  final int height;
}

class InputStyle {
  const InputStyle({this.caret = '▏', this.separator = ': '});

  final String caret;
  final String separator;
}

class ProgressStyle {
  const ProgressStyle({
    this.spinner = const <String>['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
    this.interval = const Duration(milliseconds: 80),
    this.filled = '█',
    this.empty = '░',
    this.width = 24,
    this.pending = '○',
    this.done = '✔',
    this.failed = '✖',
    this.skipped = '−',
  }) : assert(width > 0, 'ProgressStyle width must be greater than zero');

  final List<String> spinner;
  final Duration interval;
  final String filled;
  final String empty;
  final int width;
  final String pending;
  final String done;
  final String failed;
  final String skipped;
}

class ConsoleStyles {
  const ConsoleStyles({
    this.list = const ListStyle(),
    this.input = const InputStyle(),
    this.progress = const ProgressStyle(),
  });

  final ListStyle list;
  final InputStyle input;
  final ProgressStyle progress;
}
