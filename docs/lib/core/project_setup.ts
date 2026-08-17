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

import { ModuleResolutionKind, Project, ScriptTarget } from "ts-morph";

function aliasPathsFromDenoConfig(
  denoConfigPath: string,
): Record<string, string[]> {
  const source = Deno.readTextFileSync(denoConfigPath)
    .split("\n")
    .filter((line) => !line.trimStart().startsWith("//"))
    .join("\n");

  const config = JSON.parse(source) as { imports: Record<string, string> };
  const configDir = denoConfigPath.slice(0, denoConfigPath.lastIndexOf("/"));
  const paths: Record<string, string[]> = {};

  for (const [specifier, target] of Object.entries(config.imports)) {
    if (/^(npm:|jsr:|https?:)/.test(target)) continue;

    const absolute = target.startsWith("/")
      ? target
      : `${configDir}/${target.replace(/^\.\//, "")}`;

    if (specifier.endsWith("/")) {
      paths[`${specifier}*`] = [`${absolute.replace(/\/$/, "")}/*`];
    } else {
      paths[specifier] = [absolute];
    }
  }

  return paths;
}

function generatedRoot(repoRoot: string): string {
  return `${repoRoot}/.${repoRoot.split("/").filter(Boolean).pop()}`;
}

function aliasConfigPath(repoRoot: string): string {
  const generated = `${generatedRoot(repoRoot)}/sdk/js/scribe.json`;
  try {
    Deno.statSync(generated);
    return generated;
  } catch {
    console.error(
      `⚠ ${generated} is absent, falling back to the SDK config, ` +
        "which maps neither @app/ nor @artefacts/: project routes will not resolve. " +
        "Run `koko gen code` first.",
    );
    return `${repoRoot}/scribe/host/deno.json`;
  }
}

export function buildProject(repoRoot: string): Project {
  const hostRoot = `${repoRoot}/scribe/host`;
  const paths = aliasPathsFromDenoConfig(aliasConfigPath(repoRoot));

  const project = new Project({
    useInMemoryFileSystem: false,
    compilerOptions: {
      baseUrl: hostRoot,
      paths,
      target: ScriptTarget.ES2022,
      moduleResolution: ModuleResolutionKind.NodeJs,
      allowJs: false,
    },
  });

  project.addSourceFilesAtPaths([
    `${hostRoot}/api/public/**/*.ts`,
    `${repoRoot}/lib/api/**/*.ts`,
    `${hostRoot}/core/kernel/**/*.ts`,
    `${hostRoot}/core/contracts/**/*.ts`,
    `${hostRoot}/core/runtime/**/*.ts`,
    `${generatedRoot(repoRoot)}/sdk/js/**/*.ts`,
  ]);

  return project;
}
