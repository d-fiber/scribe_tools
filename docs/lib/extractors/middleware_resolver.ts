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

import { CallExpression, Node, ReturnStatement } from "ts-morph";
import { resolveBareLiteral } from "./literal_resolve.ts";
import {
  findResponseCalls,
  ServerResponseMatcher,
} from "./response_call_finder.ts";
import type { ResponseMethodInfo } from "./response_defaults.ts";
import type { LiteralResponse } from "../core/types.ts";

export interface MiddlewareValue {
  responses: LiteralResponse[];
  requiresAuth: boolean;
  requiredPermission?: string;
}

const SERVER_RESPONSE = new ServerResponseMatcher();

function containsIdentityAccess(node: Node): boolean {
  let found = false;
  node.forEachDescendant((descendant, traversal) => {
    if (found) return;
    if (
      Node.isPropertyAccessExpression(descendant) &&
      descendant.getName() === "identity"
    ) {
      found = true;
      traversal.stop();
    }
  });
  return found;
}

function resolveIndirectFunctionBody(node: Node): Node {
  if (!Node.isIdentifier(node)) return node;
  for (const def of node.getDefinitionNodes()) {
    if (Node.isFunctionDeclaration(def)) {
      const body = def.getBody();
      if (body) return body;
    }
    if (Node.isVariableDeclaration(def)) {
      const init = def.getInitializer();
      if (init) return init;
    }
  }
  return node;
}

function responsesFromBody(
  body: Node,
  defaults: Map<string, ResponseMethodInfo>,
): LiteralResponse[] {
  return findResponseCalls(body, SERVER_RESPONSE)
    .map((call) =>
      resolveBareLiteral(call.method, call.code, call.message, defaults)
    )
    .filter((r): r is LiteralResponse => r !== null);
}

export abstract class MiddlewareShape {
  abstract extract(defaults: Map<string, ResponseMethodInfo>): MiddlewareValue;

  static detect(initializer: Node): MiddlewareShape | null {
    if (Node.isCallExpression(initializer)) {
      const calleeName = initializer.getExpression().getText();
      if (calleeName === "guardMiddleware") {
        return new GuardMiddlewareShape(initializer);
      }
      if (calleeName === "createMiddleware") {
        return new CreateMiddlewareShape(initializer);
      }
      return null;
    }
    if (
      Node.isArrowFunction(initializer) ||
      Node.isFunctionExpression(initializer)
    ) {
      return new InlineFunctionShape(initializer);
    }
    return null;
  }
}

class GuardMiddlewareShape extends MiddlewareShape {
  constructor(private readonly call: CallExpression) {
    super();
  }

  extract(defaults: Map<string, ResponseMethodInfo>): MiddlewareValue {
    const [checkArg, onFailArg] = this.call.getArguments();
    return {
      responses: onFailArg ? responsesFromBody(onFailArg, defaults) : [],
      requiresAuth: checkArg
        ? containsIdentityAccess(resolveIndirectFunctionBody(checkArg))
        : false,
    };
  }
}

class CreateMiddlewareShape extends MiddlewareShape {
  constructor(private readonly call: CallExpression) {
    super();
  }

  extract(defaults: Map<string, ResponseMethodInfo>): MiddlewareValue {
    const [fnArg] = this.call.getArguments();
    if (!fnArg) return { responses: [], requiresAuth: false };
    return {
      responses: responsesFromBody(fnArg, defaults),
      requiresAuth: containsIdentityAccess(fnArg),
    };
  }
}

class InlineFunctionShape extends MiddlewareShape {
  constructor(private readonly fn: Node) {
    super();
  }

  extract(defaults: Map<string, ResponseMethodInfo>): MiddlewareValue {
    return {
      responses: responsesFromBody(this.fn, defaults),
      requiresAuth: containsIdentityAccess(this.fn),
    };
  }
}

function declarationInitializer(declaration: Node): Node | undefined {
  if (Node.isVariableDeclaration(declaration)) {
    return declaration.getInitializer();
  }

  if (Node.isFunctionDeclaration(declaration)) {
    const body = declaration.getBody();
    if (!body || !Node.isBlock(body)) return undefined;
    const returnStmt = body
      .getStatements()
      .find((s): s is ReturnStatement => Node.isReturnStatement(s));
    return returnStmt?.getExpression();
  }

  return declaration;
}

export function resolveMiddlewareValue(
  declaration: Node,
  defaults: Map<string, ResponseMethodInfo>,
): MiddlewareValue | null {
  const initializer = declarationInitializer(declaration);
  if (!initializer) return null;
  return MiddlewareShape.detect(initializer)?.extract(defaults) ?? null;
}
