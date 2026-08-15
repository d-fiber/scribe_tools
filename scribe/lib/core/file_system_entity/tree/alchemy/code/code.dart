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
import 'package:scribe/core/file_system_entity/tree/alchemy/code/rest/rest.dart';
import 'package:path/path.dart' as p;

class Code extends Node {
  final String parent;
  final String current;

  Code({required this.parent, required this.current}) : super(p.join(parent, current));

  Source get scribeJson => Source(p.join(path, "scribe.json"));
  Source get scribeContainerJson => Source(p.join(path, "scribe.container.json"));
  Source get enumsTs => Source(p.join(path, "enums.ts"));
  Source get allowedCountriesTs => Source(p.join(path, "allowed_countries.ts"));
  Source get dependenciesTs => Source(p.join(path, "dependencies.ts"));
  Source get routesTs => Source(p.join(path, "routes.ts"));
  Rest get rest => Rest(parent: path, current: "rest");
}
