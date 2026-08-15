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
  Block,
  ClassDeclaration,
  Node,
  Project,
  ReturnStatement,
  SourceFile,
} from "ts-morph";
import { extractEndpoint } from "./endpoint_walker.ts";
import {
  type MiddlewareValue,
  resolveMiddlewareValue,
} from "../extractors/middleware_resolver.ts";
import {
  ClassMountTarget,
  HonoMountTarget,
  MountTarget,
} from "./mount_target.ts";
import type { ResponseMethodInfo } from "../extractors/response_defaults.ts";
import { humanizeEndpointClassName } from "../core/summary.ts";
import type {
  GeneratedPath,
  GeneratedResponse,
  LiteralResponse,
} from "../core/types.ts";
import type { ParamBindings, WalkContext } from "../core/walk_context.ts";
import { resolveSeamModule } from "../core/seam.ts";

function warn(message: string): void {
  console.error(`⚠ ${message}`);
}

function definitionsOf(node: Node): Node[] {
  return Node.isIdentifier(node) ? node.getDefinitionNodes() : [];
}

function resolveClassDeclaration(node: Node): ClassDeclaration | null {
  return (
    definitionsOf(node).find((d): d is ClassDeclaration =>
      Node.isClassDeclaration(d)
    ) ?? null
  );
}

function toPascalCase(segment: string): string {
  return segment
    .split(/[-_]/)
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join("");
}

function computeTag(filePath: string): string {
  const match = filePath.match(/\/src\/([^/]+)\//);
  return match ? toPascalCase(match[1]) : "Unknown";
}

function joinPath(base: string, sub: string): string {
  const combined = `${base}/${sub}`.replace(/\/+/g, "/");
  return combined.length > 1 ? combined.replace(/\/$/, "") : combined;
}

function pathMatchesPrefix(subPath: string, prefix: string): boolean {
  const stripped = prefix.endsWith("/*") ? prefix.slice(0, -2) : prefix;
  return subPath === stripped || subPath.startsWith(`${stripped}/`);
}

function dedupeResponses(list: LiteralResponse[]): GeneratedResponse[] {
  const byStatus = new Map<number, Map<string, LiteralResponse>>();
  for (const r of list) {
    if (!byStatus.has(r.status)) byStatus.set(r.status, new Map());
    const key = `${r.code ?? ""} ${r.message ?? ""}`;
    byStatus.get(r.status)!.set(key, r);
  }
  return [...byStatus.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([status, variants]) => ({
      status,
      variants: [...variants.values()].map((v) => ({
        code: v.code,
        message: v.message,
      })),
    }));
}

interface AppCall {
  method: string;
  args: Node[];
}

/// Les montages d'un `if`/`else` comptent autant que ceux du corps.
///
/// Un router charge sous seam est monte conditionnellement — `if (projectApp)
/// app.route("/", projectApp)` — puisqu'il peut etre absent. Ne lire que les
/// statements de premier niveau revenait a ignorer en silence toute l'API
/// metier, sans meme un warning.
function statementsInOrder(root: SourceFile | Block): Node[] {
  const flattened: Node[] = [];

  for (const stmt of root.getStatements()) {
    if (Node.isIfStatement(stmt)) {
      for (const branch of [stmt.getThenStatement(), stmt.getElseStatement()]) {
        if (branch === undefined) continue;
        flattened.push(...(Node.isBlock(branch) ? statementsInOrder(branch) : [branch]));
      }
      continue;
    }

    if (Node.isBlock(stmt)) {
      flattened.push(...statementsInOrder(stmt));
      continue;
    }

    flattened.push(stmt);
  }

  return flattened;
}

function getAppCallsInOrder(
  root: SourceFile | Block,
  appParamName: string,
): AppCall[] {
  const calls: AppCall[] = [];
  for (const stmt of statementsInOrder(root)) {
    if (!Node.isExpressionStatement(stmt)) continue;
    const expr = stmt.getExpression();
    if (!Node.isCallExpression(expr)) continue;
    const callee = expr.getExpression();
    if (!Node.isPropertyAccessExpression(callee)) continue;
    if (callee.getExpression().getText() !== appParamName) continue;
    calls.push({ method: callee.getName(), args: expr.getArguments() });
  }
  return calls;
}

export class RouterWalker {
  constructor(
    private readonly defaults: Map<string, ResponseMethodInfo>,
    private readonly statusQualifiers: Set<string>,
    private readonly project: Project,
  ) {}

  walkEntry(entryClass: ClassDeclaration): GeneratedPath[] {
    const out: GeneratedPath[] = [];
    new ClassMountTarget(entryClass, []).walk(
      { basePath: "", bindings: new Map(), inheritedMiddleware: [] },
      this,
      out,
    );
    return out;
  }

  private resolveMiddlewareExpr(
    expr: Node,
    bindings: ParamBindings,
  ): MiddlewareValue | null {
    if (Node.isCallExpression(expr)) {
      const callee = expr.getExpression();
      const permissionArg =
        Node.isIdentifier(callee) && callee.getText() === "permission"
          ? expr.getArguments()[0]
          : undefined;

      const value = this.resolveMiddlewareExpr(callee, bindings);
      if (!value) return null;
      if (permissionArg && Node.isStringLiteral(permissionArg)) {
        return {
          ...value,
          requiredPermission: permissionArg.getLiteralValue(),
        };
      }
      return value;
    }

    if (
      Node.isPropertyAccessExpression(expr) &&
      Node.isThisExpression(expr.getExpression())
    ) {
      return bindings.get(expr.getName()) ?? null;
    }

    if (Node.isIdentifier(expr)) {
      const text = expr.getText();
      if (bindings.has(text)) return bindings.get(text) ?? null;

      for (const def of expr.getDefinitionNodes()) {
        if (
          !Node.isVariableDeclaration(def) &&
          !Node.isFunctionDeclaration(def)
        ) {
          continue;
        }
        const value = resolveMiddlewareValue(def, this.defaults);
        if (value) return value;
      }

      warn(`could not resolve middleware reference "${text}"`);
      return null;
    }

    return null;
  }

  private resolveMountTarget(
    expr: Node,
    bindings: ParamBindings,
  ): MountTarget | null {
    if (Node.isCallExpression(expr)) {
      const callee = expr.getExpression();
      if (
        Node.isPropertyAccessExpression(callee) &&
        callee.getName() === "create"
      ) {
        const classDecl = resolveClassDeclaration(callee.getExpression());
        if (!classDecl) {
          warn(`could not resolve router class for "${expr.getText()}"`);
          return null;
        }
        const callArgs = expr
          .getArguments()
          .map((a) => this.resolveMiddlewareExpr(a, bindings));
        return new ClassMountTarget(classDecl, callArgs);
      }
      return null;
    }

    if (Node.isIdentifier(expr)) {
      for (const def of expr.getDefinitionNodes()) {
        if (!Node.isVariableDeclaration(def)) continue;

        if (def.getInitializer() === undefined) {
          const seam = resolveSeamModule(this.project, def.getSourceFile(), expr.getText());
          if (seam !== undefined) return new HonoMountTarget(seam);

          warn(`could not resolve the seam behind "${expr.getText()}"`);
          return null;
        }

        return new HonoMountTarget(def.getSourceFile());
      }
    }

    warn(`could not resolve mounted app for "${expr.getText()}"`);
    return null;
  }

  private resolveHandlerEndpointClass(
    handlerArg: Node,
  ): ClassDeclaration | null {
    if (!Node.isArrowFunction(handlerArg)) return null;
    const body = handlerArg.getBody();

    let callExpr: Node | undefined;
    if (Node.isCallExpression(body)) {
      callExpr = body;
    } else if (Node.isBlock(body)) {
      const returnStmt = body
        .getStatements()
        .find((s): s is ReturnStatement => Node.isReturnStatement(s));
      if (returnStmt) {
        const returnExpr = returnStmt.getExpression();
        if (returnExpr && Node.isCallExpression(returnExpr)) {
          callExpr = returnExpr;
        }
      }
    }

    if (!callExpr || !Node.isCallExpression(callExpr)) return null;
    const callee = callExpr.getExpression();
    if (
      !Node.isPropertyAccessExpression(callee) ||
      callee.getName() !== "handle"
    ) {
      return null;
    }

    return resolveClassDeclaration(callee.getExpression());
  }

  walkHonoBody(
    root: SourceFile | Block,
    ctx: WalkContext,
    out: GeneratedPath[],
    appParamName: string,
  ): void {
    const calls = getAppCallsInOrder(root, appParamName);
    let activeGlobal: MiddlewareValue[] = [...ctx.inheritedMiddleware];
    const activeScoped: { prefix: string; value: MiddlewareValue }[] = [];

    for (const call of calls) {
      if (call.method === "use") {
        const [pathArg, ...mwArgs] = call.args;
        if (!Node.isStringLiteral(pathArg)) continue;
        const prefix = pathArg.getLiteralValue();
        const values = mwArgs
          .map((a) => this.resolveMiddlewareExpr(a, ctx.bindings))
          .filter((v): v is MiddlewareValue => v !== null);
        if (prefix === "*") {
          activeGlobal = [...activeGlobal, ...values];
        } else {
          for (const value of values) activeScoped.push({ prefix, value });
        }
        continue;
      }

      if (call.method === "route") {
        const [pathArg, honoExpr] = call.args;
        if (!Node.isStringLiteral(pathArg)) continue;
        const subPath = pathArg.getLiteralValue();
        const target = this.resolveMountTarget(honoExpr, ctx.bindings);
        if (!target) continue;

        const scopedForThis = activeScoped
          .filter((s) => pathMatchesPrefix(subPath, s.prefix))
          .map((s) => s.value);

        const childCtx: WalkContext = {
          basePath: joinPath(ctx.basePath, subPath),
          bindings: ctx.bindings,
          inheritedMiddleware: [...activeGlobal, ...scopedForThis],
        };
        target.walk(childCtx, this, out);
        continue;
      }

      if (["get", "post", "put", "patch", "delete"].includes(call.method)) {
        const [pathArg, ...rest] = call.args;
        if (!Node.isStringLiteral(pathArg) || rest.length === 0) continue;
        const subPath = pathArg.getLiteralValue();
        const handlerArg = rest[rest.length - 1];
        const inlineMiddlewareArgs = rest.slice(0, -1);

        const endpointClass = this.resolveHandlerEndpointClass(handlerArg);
        if (!endpointClass) continue;

        const scopedForThis = activeScoped
          .filter((s) => pathMatchesPrefix(subPath, s.prefix))
          .map((s) => s.value);
        const inlineValues = inlineMiddlewareArgs
          .map((a) => this.resolveMiddlewareExpr(a, ctx.bindings))
          .filter((v): v is MiddlewareValue => v !== null);

        const allMiddleware = [
          ...activeGlobal,
          ...scopedForThis,
          ...inlineValues,
        ];
        const responses: LiteralResponse[] = [];
        let requiresAuth = false;
        let requiredPermission: string | null = null;
        for (const mv of allMiddleware) {
          responses.push(...mv.responses);
          requiresAuth = requiresAuth || mv.requiresAuth;
          requiredPermission ??= mv.requiredPermission ?? null;
        }

        const extraction = extractEndpoint(endpointClass, this.defaults);
        responses.push(...extraction.responses);

        out.push({
          path: joinPath(ctx.basePath, subPath),
          method: call.method,
          tag: computeTag(endpointClass.getSourceFile().getFilePath()),
          summary: humanizeEndpointClassName(
            endpointClass.getName() ?? "",
            this.statusQualifiers,
          ),
          requiresAuth,
          requiredPermission,
          requestBody: extraction.requestBody,
          responses: dedupeResponses(responses),
        });
      }
    }
  }
}
