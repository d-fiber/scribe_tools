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

import 'package:scribe/core/file_system_entity/node.dart';
import 'package:scribe/core/file_system_entity/source.dart';
import 'package:path/path.dart' as p;

// Les quatre sorties 100 % générées de `gen code` pour le client REST kernel.
// Réécrites en entier à chaque run : aucune section écrite à la main à
// préserver, donc aucun marqueur @generated à patcher (voir rest.dart pour ce
// qui reste écrit à la main, un cran au dessus).
class Gen extends Node {
  final String parent;
  final String current;

  Gen({required this.parent, required this.current}) : super(p.join(parent, current));

  Source get rows => Source(p.join(path, "rows.ts"));
  Source get relations => Source(p.join(path, "relations.ts"));
  Source get tables => Source(p.join(path, "tables.ts"));
  Source get metadata => Source(p.join(path, "metadata.ts"));
}
