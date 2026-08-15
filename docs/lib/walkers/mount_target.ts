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

import {
  ClassDeclaration,
  ConstructorDeclaration,
  Node,
  SourceFile,
  SyntaxKind,
} from "ts-morph";
import type { MiddlewareValue } from "../extractors/middleware_resolver.ts";
import type { RouterWalker } from "./router_walker.ts";
import type { GeneratedPath } from "../core/types.ts";
import type { ParamBindings, WalkContext } from "../core/walk_context.ts";

function findSuperCallArgs(ctor: ConstructorDeclaration): Node[] | null {
  const body = ctor.getBody();
  if (!body) return null;
  const superCall = body
    .getDescendantsOfKind(SyntaxKind.CallExpression)
    .find((c) => c.getExpression().getKind() === SyntaxKind.SuperKeyword);
  return superCall ? superCall.getArguments() : null;
}

function findFieldAssignments(
  ctor: ConstructorDeclaration,
): { fieldName: string; paramName: string }[] {
  const body = ctor.getBody();
  if (!body) return [];
  const results: { fieldName: string; paramName: string }[] = [];
  for (const bin of body.getDescendantsOfKind(SyntaxKind.BinaryExpression)) {
    if (bin.getOperatorToken().getText() !== "=") continue;
    const left = bin.getLeft();
    const right = bin.getRight();
    if (!Node.isPropertyAccessExpression(left)) continue;
    if (!Node.isThisExpression(left.getExpression())) continue;
    if (!Node.isIdentifier(right)) continue;
    results.push({ fieldName: left.getName(), paramName: right.getText() });
  }
  return results;
}

export abstract class MountTarget {
  abstract walk(
    ctx: WalkContext,
    walker: RouterWalker,
    out: GeneratedPath[],
  ): void;
}

export class ClassMountTarget extends MountTarget {
  constructor(
    private readonly decl: ClassDeclaration,
    private readonly callArgs: (MiddlewareValue | null)[],
  ) {
    super();
  }

  walk(ctx: WalkContext, walker: RouterWalker, out: GeneratedPath[]): void {
    const ctor = this.decl.getConstructors()[0];
    const bindings: ParamBindings = new Map();
    let implicitMiddleware: MiddlewareValue | null = null;

    if (ctor) {
      const params = ctor.getParameters();
      params.forEach((param, i) => {
        bindings.set(param.getName(), this.callArgs[i] ?? null);
      });

      const superArgs = findSuperCallArgs(ctor);
      if (
        superArgs &&
        superArgs.length > 0 &&
        Node.isIdentifier(superArgs[0])
      ) {
        implicitMiddleware = bindings.get(superArgs[0].getText()) ?? null;
      }

      for (const { fieldName, paramName } of findFieldAssignments(ctor)) {
        bindings.set(fieldName, bindings.get(paramName) ?? null);
      }
    } else {
      implicitMiddleware = this.callArgs[0] ?? null;
    }

    const routesMethod = this.decl.getMethod("routes");
    if (!routesMethod) {
      return;
    }
    const body = routesMethod.getBody();
    if (!body || !Node.isBlock(body)) return;

    const appParamName = routesMethod.getParameters()[0]?.getName() ?? "app";
    const newCtx: WalkContext = {
      basePath: ctx.basePath,
      bindings,
      inheritedMiddleware: implicitMiddleware
        ? [...ctx.inheritedMiddleware, implicitMiddleware]
        : ctx.inheritedMiddleware,
    };
    walker.walkHonoBody(body, newCtx, out, appParamName);
  }
}

export class HonoMountTarget extends MountTarget {
  constructor(private readonly sourceFile: SourceFile) {
    super();
  }

  walk(ctx: WalkContext, walker: RouterWalker, out: GeneratedPath[]): void {
    const varDecl = this.sourceFile.getVariableDeclarations().find((v) => {
      const init = v.getInitializer();
      return (
        init &&
        Node.isNewExpression(init) &&
        init.getExpression().getText() === "Hono"
      );
    });
    if (!varDecl) {
      return;
    }
    walker.walkHonoBody(this.sourceFile, ctx, out, varDecl.getName());
  }
}
