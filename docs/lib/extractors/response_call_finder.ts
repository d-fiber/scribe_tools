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

import { Node } from "ts-morph";

export interface RawResponseCall {
  method: string;
  code: string | null;
  message: string | null;
}

export abstract class ResponseCallMatcher {
  abstract matches(receiver: Node): boolean;
}

export class ThisResponseMatcher extends ResponseCallMatcher {
  matches(receiver: Node): boolean {
    return (
      Node.isPropertyAccessExpression(receiver) &&
      Node.isThisExpression(receiver.getExpression()) &&
      receiver.getName() === "response"
    );
  }
}

export class ServerResponseMatcher extends ResponseCallMatcher {
  matches(receiver: Node): boolean {
    return (
      Node.isIdentifier(receiver) && receiver.getText() === "ServerResponse"
    );
  }
}

export function findResponseCalls(
  root: Node,
  matcher: ResponseCallMatcher,
): RawResponseCall[] {
  const calls: RawResponseCall[] = [];

  root.forEachDescendant((node) => {
    if (!Node.isCallExpression(node)) return;
    const callee = node.getExpression();
    if (!Node.isPropertyAccessExpression(callee)) return;
    if (!matcher.matches(callee.getExpression())) return;

    const method = callee.getName();
    const args = node.getArguments();
    let code: string | null = null;
    let message: string | null = null;

    if (args.length > 0 && Node.isObjectLiteralExpression(args[0])) {
      for (const prop of args[0].getProperties()) {
        if (!Node.isPropertyAssignment(prop)) continue;
        const name = prop.getName();
        const init = prop.getInitializer();
        if (!init || !Node.isStringLiteral(init)) continue;
        if (name === "code") code = init.getLiteralValue();
        if (name === "message") message = init.getLiteralValue();
      }
    }

    calls.push({ method, code, message });
  });

  return calls;
}
