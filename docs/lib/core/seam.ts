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

import { Node, Project, SourceFile, SyntaxKind } from "ts-morph";

function specifierOfDynamicImport(node: Node): string | null {
  const call = Node.isAwaitExpression(node) ? node.getExpression() : node;
  if (!Node.isCallExpression(call)) return null;
  if (call.getExpression().getKind() !== SyntaxKind.ImportKeyword) return null;

  const [specifier] = call.getArguments();
  return specifier !== undefined && Node.isStringLiteral(specifier)
    ? specifier.getLiteralValue()
    : null;
}

function resolveThroughAliases(
  project: Project,
  specifier: string,
): SourceFile | undefined {
  const paths = project.getCompilerOptions().paths ?? {};

  for (const [pattern, targets] of Object.entries(paths)) {
    if (!pattern.endsWith("*")) {
      if (pattern !== specifier) continue;
      return project.getSourceFile(targets[0]);
    }

    const prefix = pattern.slice(0, -1);
    if (!specifier.startsWith(prefix)) continue;

    const rest = specifier.slice(prefix.length);
    for (const target of targets) {
      const candidate = project.getSourceFile(target.replace(/\*$/, "") + rest);
      if (candidate !== undefined) return candidate;
    }
  }

  return undefined;
}

export function resolveSeamModule(
  project: Project,
  sourceFile: SourceFile,
  boundName: string,
): SourceFile | undefined {
  for (const assignment of sourceFile.getDescendantsOfKind(
    SyntaxKind.BinaryExpression,
  )) {
    if (assignment.getOperatorToken().getText() !== "=") continue;

    const target = assignment.getLeft();
    if (!Node.isObjectLiteralExpression(target)) continue;

    const binds = target
      .getProperties()
      .some(
        (property) =>
          Node.isPropertyAssignment(property) &&
          property.getInitializer()?.getText() === boundName,
      );
    if (!binds) continue;

    const specifier = specifierOfDynamicImport(assignment.getRight());
    if (specifier === null) continue;

    return resolveThroughAliases(project, specifier);
  }

  return undefined;
}
