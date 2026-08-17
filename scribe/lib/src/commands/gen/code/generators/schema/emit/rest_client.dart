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

import 'package:scribe/src/commands/gen/code/generators/schema/emit/generated_header.dart';

/// The lines of `client.ts`: the one surface a query starts from.
///
/// There is a single client, on the service role. Restricting a query to its
/// owner is the builder's job — it injects the owning column from the identity
/// carried by the request — so the client itself holds no scope.
///
/// `_owners.ts` is imported for its side effect: it registers the owning column
/// of every table when it loads. Without it no project table has a known owner,
/// so none is bounded to its user.
List<String> renderRestClient() => <String>[
  ...generatedHeader(),
  'import "./_owners.ts";',
  'import { PostgrestClients } from "@scribe/core/clients/database/client.ts";',
  'import { ProjectTables } from "./tables.ts";',
  '',
  'export class ProjectRestClient extends ProjectTables {}',
  '',
  'export const rest = new ProjectRestClient(() => PostgrestClients.service());',
  '',
];
