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

import { Node, Project } from "ts-morph";

export interface ResponseMethodInfo {
  status: number;
  defaultCode: string | null;
  defaultMessage: string | null;
}

function stripQuotes(text: string): string {
  return text.replace(/^["'`]|["'`]$/g, "");
}

export function extractResponseDefaults(
  project: Project,
  responsesFilePath: string,
): Map<string, ResponseMethodInfo> {
  const sourceFile = project.getSourceFileOrThrow(responsesFilePath);
  const serverResponse = sourceFile.getClassOrThrow("ServerResponse");
  const result = new Map<string, ResponseMethodInfo>();

  for (const prop of serverResponse.getStaticMembers()) {
    if (!Node.isPropertyDeclaration(prop)) continue;
    const initializer = prop.getInitializer();
    if (!initializer || !Node.isCallExpression(initializer)) continue;

    const callee = initializer.getExpression().getText();
    const args = initializer.getArguments();
    const name = prop.getName();

    if (callee === "_successResponseFactory") {
      const status = Number(args[0].getText());
      result.set(name, {
        status,
        defaultCode: "success",
        defaultMessage: null,
      });
    } else if (
      callee === "_clientErrorResponseFactory" ||
      callee === "_fixedErrorResponseFactory"
    ) {
      const defaultCode = stripQuotes(args[0].getText());
      const defaultMessage = stripQuotes(args[1].getText());
      const status = Number(args[2].getText());
      result.set(name, { status, defaultCode, defaultMessage });
    }
  }

  return result;
}
