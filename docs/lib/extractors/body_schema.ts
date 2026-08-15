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

import { CallExpression, Node, ObjectLiteralExpression } from "ts-morph";
import type { RequestBodyField, RequestBodyFieldType } from "../core/types.ts";

const CTOR_TYPES: Record<string, RequestBodyFieldType> = {
  String: "string",
  Number: "number",
  Boolean: "boolean",
  Object: "object",
  File: "file",
};

function isCallNamed(node: Node, name: string): node is CallExpression {
  return Node.isCallExpression(node) && node.getExpression().getText() === name;
}

export abstract class BodyFieldShape {
  abstract resolve(): Omit<RequestBodyField, "name">;

  static from(node: Node): BodyFieldShape {
    if (isCallNamed(node, "Required")) {
      return new RequiredShape(node.getArguments()[0]);
    }
    if (isCallNamed(node, "Nested")) {
      return new NestedShape(node.getArguments()[0]);
    }
    if (isCallNamed(node, "Arr")) return new ArrayShape(node.getArguments()[0]);
    return new ScalarShape(node);
  }
}

class RequiredShape extends BodyFieldShape {
  constructor(private readonly inner: Node) {
    super();
  }

  resolve(): Omit<RequestBodyField, "name"> {
    return { ...BodyFieldShape.from(this.inner).resolve(), required: true };
  }
}

class NestedShape extends BodyFieldShape {
  constructor(private readonly inner: Node) {
    super();
  }

  resolve(): Omit<RequestBodyField, "name"> {
    if (!Node.isObjectLiteralExpression(this.inner)) {
      return { type: "object", required: false };
    }
    return {
      type: "nested",
      required: false,
      properties: buildFields(this.inner),
    };
  }
}

class ArrayShape extends BodyFieldShape {
  constructor(private readonly itemNode: Node) {
    super();
  }

  resolve(): Omit<RequestBodyField, "name"> {
    const item = BodyFieldShape.from(this.itemNode).resolve();
    return { type: "array", required: false, items: { name: "", ...item } };
  }
}

class ScalarShape extends BodyFieldShape {
  constructor(private readonly node: Node) {
    super();
  }

  resolve(): Omit<RequestBodyField, "name"> {
    return {
      type: CTOR_TYPES[this.node.getText()] ?? "string",
      required: false,
    };
  }
}

function buildFields(obj: ObjectLiteralExpression): RequestBodyField[] {
  const fields: RequestBodyField[] = [];
  for (const prop of obj.getProperties()) {
    if (!Node.isPropertyAssignment(prop)) continue;
    const name = prop.getName();
    const init = prop.getInitializer();
    if (!init) continue;
    fields.push({ name, ...BodyFieldShape.from(init).resolve() });
  }
  return fields;
}

export function findBodyOrFormSchema(root: Node): RequestBodyField[] | null {
  let result: ObjectLiteralExpression | null = null;

  root.forEachDescendant((node, traversal) => {
    if (result) return;
    if (!Node.isCallExpression(node)) return;
    const callee = node.getExpression();
    if (!Node.isPropertyAccessExpression(callee)) return;
    if (!Node.isThisExpression(callee.getExpression())) return;
    const name = callee.getName();
    if (name !== "body" && name !== "form") return;

    const arg = node.getArguments()[0];
    if (arg && Node.isObjectLiteralExpression(arg)) {
      result = arg;
      traversal.stop();
    }
  });

  return result ? buildFields(result) : null;
}
