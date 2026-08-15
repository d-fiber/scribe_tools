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

import { assert, assertEquals } from "jsr:@std/assert@1";

const repoRoot = new URL("../../../../", import.meta.url).pathname.replace(/\/$/, "");

/// Les fichiers du SDK que le walker adresse par chemin, pas par alias.
///
/// C'est exactement ce qui l'avait mis hors service : `kernel/` a demenage dans
/// `caleb/` sans que ces chemins suivent, le walker plantait au demarrage, et
/// rien ne le signalait puisque personne ne lancait `gen docs`.
const hardcodedTargets: string[] = [
  "scribe/host/core/kernel/http/response/json.ts",
  "scribe/host/core/contracts/enums.ts",
  "scribe/host/api/public/admin/index.ts",
  "scribe/host/api/public/app/index.ts",
];

/// Les racines que `buildProject` charge dans le projet ts-morph.
const sourceRoots: string[] = [
  "scribe/host/api/public",
  "scribe/host/core/kernel",
  "scribe/host/core/contracts",
  "scribe/host/core/runtime",
  "lib/api",
];

function exists(path: string): boolean {
  try {
    Deno.statSync(`${repoRoot}/${path}`);
    return true;
  } catch {
    return false;
  }
}

Deno.test("every file the walker addresses by path still exists", () => {
  assertEquals(hardcodedTargets.filter((path) => !exists(path)), []);
});

Deno.test("every source root the walker loads still exists", () => {
  assertEquals(sourceRoots.filter((path) => !exists(path)), []);
});

Deno.test("the walker sources its aliases from the generated map, not the SDK one", async () => {
  const setup = await Deno.readTextFile(`${repoRoot}/scribe/tools/docs/lib/core/project_setup.ts`);

  assert(
    setup.includes("generatedRoot(repoRoot)}/sdk/js/scribe.json"),
    "buildProject must read the generated sdk/js/scribe.json — the SDK config maps neither @app/ nor the " +
      "project alias, so no project route can resolve without it.",
  );
});
