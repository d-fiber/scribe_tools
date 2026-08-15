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

import { extractEnumMemberNames } from "./lib/extractors/enum_extractor.ts";
import { buildProject } from "./lib/core/project_setup.ts";
import { extractResponseDefaults } from "./lib/extractors/response_defaults.ts";
import { RouterWalker } from "./lib/walkers/router_walker.ts";
import type { GeneratedPathsDocument } from "./lib/core/types.ts";

function parseArgs(): { surface: string; root: string } {
  const surfaceArg = Deno.args.find((a) => a.startsWith("--surface="));
  const rootArg = Deno.args.find((a) => a.startsWith("--root="));
  if (!surfaceArg || !rootArg) {
    throw new Error(
      "usage: walk_routes.ts --surface=<key> --root=<repoRoot>",
    );
  }
  const surface = surfaceArg.slice("--surface=".length);
  if (!/^[a-z][a-z0-9-]*$/.test(surface)) {
    throw new Error(`invalid --surface value: ${surface}`);
  }
  return { surface, root: rootArg.slice("--root=".length) };
}

function main(): void {
  const { surface, root } = parseArgs();
  const project = buildProject(root);
  const defaults = extractResponseDefaults(
    project,
    `${root}/scribe/host/core/kernel/http/response/json.ts`,
  );
  const statusQualifiers = extractEnumMemberNames(
    project,
    [
      `${root}/.${root.split("/").filter(Boolean).pop()}/sdk/js/enums.ts`,
      `${root}/scribe/host/core/contracts/enums.ts`,
    ],
    "Status",
  );

  const entryPath =
    `${root}/scribe/host/api/public/${surface}/index.ts`;
  const entrySourceFile = project.getSourceFileOrThrow(entryPath);
  const entryClass = entrySourceFile
    .getClasses()
    .find((c) => c.getExtends()?.getText() === "Router");

  if (!entryClass) {
    throw new Error(`no Router subclass found in ${entryPath}`);
  }

  const walker = new RouterWalker(defaults, statusQualifiers, project);
  const paths = walker.walkEntry(entryClass);
  paths.sort((a, b) =>
    a.path === b.path
      ? a.method.localeCompare(b.method)
      : a.path.localeCompare(b.path)
  );

  const document: GeneratedPathsDocument = { surface, paths };
  console.log(JSON.stringify(document));
}

main();
